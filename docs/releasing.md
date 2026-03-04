# Releasing Prebuilt NIFs

1. Trigger the **Precompile NIFs** workflow (`workflow_dispatch`) with the version tag (e.g. `v0.1.0`)
2. Workflow compiles 8 platforms, uploads to draft GitHub release, updates `precompiled.ex`, and opens a PR automatically
3. Merge the auto-PR with updated shasums
4. Tag: `git pull && git tag vX.Y.Z && git push origin vX.Y.Z`
5. Undraft: `gh release edit vX.Y.Z --draft=false`
6. Publish: `mix hex.publish && mix hex.publish docs`

## Force Source Compilation

For local testing, skip prebuilt NIFs:

```
ZIGLER_PRECOMPILE_FORCE_RECOMPILE=true mix compile
```
