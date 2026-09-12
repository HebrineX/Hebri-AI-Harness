# Packaging P06

This directory defines the Windows x64, per-machine packaging input for
Hebri-AI-Harness 0.17.1.

- `runtime-layout.json` classifies source paths and target paths.
- `release.json` is deterministic release metadata copied as `release.json`.
- `toolchain-lock.json` records locally verified build inputs and the unresolved
  distribution review.
- `launcher/HebrinexLauncher.cs` is compiled for .NET Framework 4.8.
- `msi/Package.wxs` is declarative WiX authoring with no custom actions.

The build scripts publish only below `artifacts/p06`. The resulting MSI is an
unsigned local engineering candidate. P06 does not authorize installation,
elevation, signing, release publication or a real PATH/registry mutation.
