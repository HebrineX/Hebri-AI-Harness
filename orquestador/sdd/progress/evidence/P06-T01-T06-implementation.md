# P06-T01..T06 - Implementation evidence

Cycle: `C-010`. Execution mode: explicit simulated roles. The leader
coordinated; `A-P06-I01` produced the implementation after the detractor pass.

## Frozen local decision

- Target: Windows x64, per-machine, `%ProgramFiles%\Hebri-AI-Harness`.
- Core engine: system Windows PowerShell 5.1; no bundled `pwsh`.
- Launcher: .NET Framework 4.8 executable, compiled deterministically with
  Roslyn `5.3.0-2.26230.114` from .NET SDK `10.0.204`.
- Installer: WiX `5.0.2+aa65968c`, declarative, unsigned, no custom actions.
- MCP: source present, direct `zod 4.4.3` pinned, but no redistributed Node or
  `node_modules`; launcher returns `OPTIONAL_FEATURE_MISSING`.
- Release status: `unsigned_local_engineering_candidate`; external
  distribution/license review remains pending.

## Implemented surface

- Exact payload builder, launcher builder, MSI builder and packaging validator.
- Payload/release/toolchain schemas and templates.
- Runtime layout classification for its own authority, release metadata and
  packaged legacy baselines; source-only builders remain denied.
- WiX package with stable ProductCode/UpgradeCode, x64 Program Files directory,
  HKLM InstallRoot/version/API values and system PATH entry.
- Release-manifest-authoritative baselines. `v0.10.11` has 346 files and tree
  `4dac3b389716a1fe21a2cef00097e32d213a9b724aad77353615269fabed7632`;
  `v0.16.0` has 391 files and tree
  `880666a0bc555f5db6f010abbee72ae4a67ad587d8134d0d01bf9931da2c1bcb`.
  Undeclared `infoHebriHarness.md` is absent; declared security-policy files
  remain product.

## Final artifacts

- Payload: 447 manifest entries, tree
  `cb0eb8f2a242f5868ae010767ec16bc2c08dfec93d325e03b5863ca26f7cd2ce`.
- Source manifest SHA-256:
  `053faa28a052066fed062e88432fe78249ab456ec946d00f9dd1b7ac5facee8c`.
- Payload manifest SHA-256:
  `fe0bc3504c69c33ec49119a131663338dbade2c25ea85f3790b802e7bea4fc00`.
- Launcher: 16,896 bytes, SHA-256
  `4c97f47936a3f5f5349a274e6ad27165aacb03646429df84b11058415c739697`.
- MSI: 504,152 bytes, SHA-256
  `7c836b9bc639f2cd7ae533dee310c268e2bfeda5eea87bbfc831c963f9f58aa0`.

All outputs are ignored under `artifacts/p06`. No network, installation,
elevation, signing, Git write, CI remote, real consumer or real PATH/registry
mutation was performed.
