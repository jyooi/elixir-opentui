#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
version="1.7.4"
sha256="936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
jar="${TLA2TOOLS_JAR:-${XDG_CACHE_HOME:-$HOME/.cache}/tla2tools/$version/tla2tools.jar}"

if [ ! -f "$jar" ]; then
  mkdir -p "$(dirname "$jar")"
  curl -fsSL -o "$jar" "https://github.com/tlaplus/tlaplus/releases/download/v$version/tla2tools.jar"
fi
echo "$sha256  $jar" | sha256sum -c --quiet

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp "$here/RuntimeTick.tla" "$work/"
status=0

echo "== Model (TLC $version)"
while read -r rule expected; do
  grep -v -e '^INVARIANTS' -e '^  [A-Z][A-Za-z]*$' "$here/RuntimeTick.cfg" > "$work/RuntimeTick.cfg"
  printf 'INVARIANT %s\n' "$rule" >> "$work/RuntimeTick.cfg"
  out="$work/$rule.out"
  (cd "$work" && java -XX:+UseParallelGC -cp "$jar" tlc2.TLC -workers 1 -metadir "$work/states-$rule" -config RuntimeTick.cfg RuntimeTick.tla > "$out" 2>&1) || true

  if grep -q "Invariant $rule is violated" "$out"; then actual="breaks"
  elif grep -q "Model checking completed. No error has been found" "$out"; then actual="holds"
  else actual="error"; fi

  if [ "$actual" = "$expected" ]; then
    note="as recorded"
    [ "$actual" = "breaks" ] && note="KNOWN FINDING, as recorded"
    echo "  $rule: $actual ($note)"
  else
    echo "  $rule: $actual, but expected.txt records '$expected'  <== CHANGED"
    [ "$actual" = "error" ] && tail -20 "$out"
    status=1
  fi
done < "$here/expected.txt"

echo "== Real code (ExUnit)"
cd "$repo"
if mix test test/elixir_opentui/runtime_tick_model_test.exs > "$work/pass.out" 2>&1; then
  echo "  rules that hold: pass"
else
  echo "  rules that hold: FAIL  <== CHANGED"
  grep -v -e 'debug\]' -e 'info\]' "$work/pass.out" | tail -30
  status=1
fi

findings="$(grep -c ' breaks$' "$here/expected.txt" || true)"
if [ "$findings" = 0 ]; then
  echo "  known findings: none recorded"
elif mix test test/elixir_opentui/runtime_tick_model_test.exs --only known_finding > "$work/findings.out" 2>&1; then
  if [ "$findings" -gt 0 ]; then
    echo "  known findings: all replays pass now, but expected.txt records $findings breaks  <== CHANGED"
    status=1
  else
    echo "  known findings: none"
  fi
else
  failed="$(grep -c '^ *[0-9]*) test ' "$work/findings.out" || true)"
  if [ "$failed" = "$findings" ]; then
    echo "  known findings: $failed replays fail (as recorded)"
  else
    echo "  known findings: $failed replays fail, but expected.txt records $findings breaks  <== CHANGED"
    status=1
  fi
fi

[ "$status" = 0 ] && echo "RESULT: same as recorded" || echo "RESULT: CHANGED - read the skill verify-runtime-tick-loop"
exit "$status"
