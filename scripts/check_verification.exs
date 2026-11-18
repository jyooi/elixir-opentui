defmodule CheckVerification do
  @root Path.expand("..", __DIR__)
  @skill "verify-runtime-tick-loop"
  @skill_path ".claude/skills/#{@skill}"
  @chart_dir "#{@skill_path}/charts"
  @default_branch "origin/main"
  @passed "Model checking completed. No error has been found."

  def run do
    started = System.monotonic_time(:millisecond)
    {problems, notes} = check()
    seconds = Float.round((System.monotonic_time(:millisecond) - started) / 1000, 1)
    Enum.each(notes, &IO.puts/1)

    if problems == [] do
      IO.puts("Verification passed in #{seconds} s.")
    else
      IO.puts(:stderr, "Verification failed in #{seconds} s:\n\n#{Enum.join(problems, "\n\n")}")
      System.halt(1)
    end
  end

  defp check do
    if skill?() do
      record = JSON.decode!(File.read!(Path.join([@root, @skill_path, "record.json"])))

      [
        fn -> {check_record(record), []} end,
        fn -> check_model(record) end,
        fn -> check_code(record) end,
        fn -> check_chart(branch()) end
      ]
      |> parallel()
      |> merge()
    else
      {[
         "The repository has no verification skill. Expected #{@skill_path}/SKILL.md with name and description frontmatter, and record.json beside it."
       ], []}
    end
  end

  defp parallel(jobs) do
    jobs
    |> Task.async_stream(& &1.(), timeout: :infinity)
    |> Enum.map(fn {:ok, outcome} -> outcome end)
  end

  defp merge(outcomes) do
    {Enum.flat_map(outcomes, &elem(&1, 0)), Enum.flat_map(outcomes, &elem(&1, 1))}
  end

  defp skill? do
    with true <- File.exists?(Path.join([@root, @skill_path, "record.json"])),
         {:ok, text} <- File.read(Path.join([@root, @skill_path, "SKILL.md"])),
         [_, frontmatter] <- Regex.run(~r/\A---\n(.*?)\n---\n/s, text) do
      frontmatter =~ ~r/^name: #{@skill}$/m and frontmatter =~ ~r/^description: \S/m
    else
      _ -> false
    end
  end

  defp verified_files(%{"covers" => covers, "model" => model}) do
    covers ++
      [
        %{"file" => "#{@skill_path}/#{model["spec"]}", "sha256" => model["specSha256"]},
        %{"file" => "#{@skill_path}/#{model["config"]}", "sha256" => model["configSha256"]}
      ]
  end

  defp check_record(record) do
    Enum.flat_map(verified_files(record), fn %{"file" => file, "sha256" => recorded} ->
      case File.read(Path.join(@root, file)) do
        {:error, _} ->
          [
            "Verified file #{file} is missing. Follow the #{@skill} skill to update the model and record.json."
          ]

        {:ok, data} ->
          case sha256(data) do
            ^recorded ->
              []

            actual ->
              [
                "Verified code changed and the verification record did not: #{file} has SHA-256 #{actual}, and record.json has #{recorded}. Follow the #{@skill} skill to confirm the model, then record the new digest."
              ]
          end
      end
    end)
  end

  defp check_model(%{"model" => model, "properties" => properties, "tool" => tool}) do
    spec_name = model["spec"]
    spec = File.read!(Path.join([@root, @skill_path, spec_name]))
    config = File.read!(Path.join([@root, @skill_path, model["config"]]))

    {base, configured} =
      case String.split(config, ~r/^INVARIANTS\n/m, parts: 2) do
        [base, block] -> {base, String.split(block)}
        [base] -> {base, []}
      end

    recorded = Enum.map(properties, & &1["name"])

    list_problems =
      if configured == recorded,
        do: [],
        else: [
          "#{model["config"]} lists the invariants #{Enum.join(configured, ", ")}, and record.json lists #{Enum.join(recorded, ", ")}. Make the two lists the same."
        ]

    with_invariants = fn names -> base <> "INVARIANTS\n" <> Enum.map_join(names, &"  #{&1}\n") end
    jar = tla_tools(tool)
    {holding, findings} = Enum.split_with(properties, &(&1["status"] == "holds"))
    holding_names = Enum.map(holding, & &1["name"])

    holds_run = fn ->
      {output, code} = tlc(jar, spec_name, spec, with_invariants.(holding_names), true)

      if code == 0 and String.contains?(output, @passed) do
        states = Regex.run(~r/([\d,]+) distinct states found/, output) |> Enum.at(1, "?")

        {[],
         [
           "Properties that hold: #{Enum.join(holding_names, ", ")}.",
           "TLC #{tool["version"]} checked #{states} distinct states."
         ]}
      else
        {["The verification check fails:\n#{tlc_error(output)}"], []}
      end
    end

    finding_runs =
      for %{"name" => name} <- findings do
        fn -> finding_run(name, jar, spec_name, spec, with_invariants) end
      end

    break_runs =
      for property <- holding do
        fn -> break_run(property, jar, spec_name, spec, with_invariants) end
      end

    {problems, notes} = merge(parallel([holds_run | finding_runs ++ break_runs]))
    {list_problems ++ problems, notes}
  end

  defp finding_run(name, jar, spec_name, spec, with_invariants) do
    {output, code} = tlc(jar, spec_name, spec, with_invariants.([name]), false)

    cond do
      violated?(output, name) ->
        {[], ["Recorded finding #{name} still breaks."]}

      code == 0 ->
        {[
           "The recorded finding #{name} no longer breaks. Confirm the fix, set its status to holds, and record a break for it."
         ], []}

      true ->
        {["The verification check fails on #{name}:\n#{tlc_error(output)}"], []}
    end
  end

  defp break_run(%{"name" => name} = property, jar, spec_name, spec, with_invariants) do
    case property["break"] do
      %{"find" => find, "replace" => replace} ->
        if length(String.split(spec, find)) == 2 do
          broken = String.replace(spec, find, replace)
          {output, _} = tlc(jar, spec_name, broken, with_invariants.([name]), false)

          if violated?(output, name),
            do: {[], ["Recorded break of #{name} is caught."]},
            else:
              {[
                 "The verification does not catch the recorded break of #{name}. The property cannot fail, so correct the model or the property."
               ], []}
        else
          {[
             "The recorded break of #{name} does not match the model exactly one time. Update the break in record.json."
           ], []}
        end

      _ ->
        {["Property #{name} has no recorded break in record.json."], []}
    end
  end

  defp tla_tools(%{"version" => version, "url" => url, "sha256" => pinned}) do
    cache = System.get_env("XDG_CACHE_HOME") || Path.join(System.user_home!(), ".cache")
    jar = Path.join([cache, "tla2tools", version, "tla2tools.jar"])

    unless File.exists?(jar) do
      download = jar <> ".download"
      File.mkdir_p!(Path.dirname(jar))

      case System.cmd("curl", ["-fsSL", "-o", download, url], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> raise "Cannot download #{url}: #{output}"
      end

      actual = sha256(File.read!(download))

      if actual != pinned do
        File.rm!(download)
        raise "#{url} has SHA-256 #{actual}, not the pinned #{pinned}"
      end

      File.rename!(download, jar)
    end

    actual = sha256(File.read!(jar))
    if actual != pinned, do: raise("#{jar} has SHA-256 #{actual}, not the pinned #{pinned}")
    jar
  end

  defp tlc(jar, spec_name, spec, config, check_deadlock?) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "#{@skill}-#{:os.getpid()}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)

    try do
      File.write!(Path.join(dir, spec_name), spec)
      File.write!(Path.join(dir, "Check.cfg"), config)

      args =
        ["-XX:+UseParallelGC", "-Djava.io.tmpdir=#{dir}", "-cp", jar, "tlc2.TLC"] ++
          ["-workers", "1", "-fp", "0"] ++
          if(check_deadlock?, do: [], else: ["-deadlock"]) ++
          ["-metadir", Path.join(dir, "states"), "-config", "Check.cfg", spec_name]

      System.cmd("java", args, cd: dir, stderr_to_stdout: true)
    after
      File.rm_rf!(dir)
    end
  end

  defp violated?(output, name), do: String.contains?(output, "Invariant #{name} is violated")

  defp tlc_error(output) do
    lines = String.split(output, "\n")
    start = Enum.find_index(lines, &String.starts_with?(&1, "Error:")) || 0
    lines |> Enum.drop(start) |> Enum.take(200) |> Enum.join("\n")
  end

  defp check_code(%{"test" => test}) do
    case System.cmd("mix", ["test", test], cd: @root, stderr_to_stdout: true) do
      {_, 0} ->
        {[], ["Real-code test #{test}: pass."]}

      {output, _} ->
        tail =
          case String.split(output, "Running ExUnit", parts: 2) do
            [_, run] -> "Running ExUnit" <> run
            [_] -> output |> String.split("\n") |> Enum.take(-60) |> Enum.join("\n")
          end

        {[
           "The real-code test #{test} fails. Follow the #{@skill} skill to read the result:\n#{tail}"
         ], []}
    end
  end

  defp branch do
    case System.get_env("GITHUB_HEAD_REF") do
      head when head not in [nil, ""] ->
        head

      _ ->
        case git(["symbolic-ref", "--quiet", "--short", "HEAD"]) do
          {:ok, name} -> name
          :error -> nil
        end
    end
  end

  defp git(args) do
    case System.cmd("git", args, cd: @root, stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      _ -> :error
    end
  end

  defp chart_file(branch),
    do: "#{@chart_dir}/#{String.replace(branch, ~r/[^A-Za-z0-9._-]/, "-")}.md"

  defp check_chart(branch) do
    with {:ok, base} <- git(["merge-base", @default_branch, "HEAD"]),
         {:ok, head} <- git(["rev-parse", "HEAD"]) do
      if base == head,
        do:
          {[],
           ["State chart file: not checked, because HEAD has no change from #{@default_branch}."]},
        else: check_charts(base, branch)
    else
      :error ->
        {[
           "Cannot find the merge base of HEAD and #{@default_branch}. Fetch #{@default_branch} with the full history."
         ], []}
    end
  end

  defp check_charts(base, branch) do
    {:ok, diff} = git(["diff", "--name-status", "--no-renames", base, "HEAD"])

    charts =
      for line <- String.split(diff, "\n", trim: true),
          [status, path] = String.split(line, "\t"),
          status != "D",
          Path.dirname(path) == @chart_dir,
          String.ends_with?(path, ".md"),
          do: path

    expected = branch && chart_file(branch)

    cond do
      expected && expected not in charts ->
        {[
           "The change adds or changes no state chart file #{expected} for the branch #{branch}. Follow the #{@skill} skill to add one."
         ], []}

      charts == [] ->
        {[
           "The change adds or changes no state chart file in #{@chart_dir}. Follow the #{@skill} skill to add one."
         ], []}

      true ->
        case Enum.flat_map(charts, &chart_problems/1) do
          [] -> {[], ["State chart file: #{Enum.join(charts, ", ")}."]}
          problems -> {problems, []}
        end
    end
  end

  defp chart_problems(chart) do
    text = committed(chart) || ""

    case chart_digest(text) do
      nil ->
        if text =~ ~r/^No state change\b/m,
          do: [],
          else: ["#{chart} has no mermaid chart and no \"No state change\" note."]

      drawn ->
        image_problems(chart, drawn)
    end
  end

  defp image_problems(chart, drawn) do
    image = String.replace_suffix(chart, ".md", ".svg")

    case committed(image) do
      nil ->
        [
          "#{chart} has a chart, and no SVG image #{image} is beside it. Render the chart to that file as the #{@skill} skill says."
        ]

      svg ->
        case Regex.run(~r/Chart digest: ([0-9a-f]{64})/, svg, capture: :all_but_first) do
          [^drawn] ->
            []

          named ->
            [
              "#{image} is older than the chart text of #{chart}: the image names chart digest #{List.first(named || ["none"])}, and the chart text has #{drawn}. Render the image again from the chart text, and write the new digest in it."
            ]
        end
    end
  end

  defp committed(path) do
    case git(["show", "HEAD:#{path}"]) do
      {:ok, text} -> text
      :error -> nil
    end
  end

  defp chart_digest(text) do
    case Regex.run(~r/^```mermaid[ \t]*\n(.*?)^```[ \t]*$/ms, text, capture: :all_but_first) do
      [body] -> sha256(body)
      nil -> nil
    end
  end

  defp sha256(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
end

CheckVerification.run()
