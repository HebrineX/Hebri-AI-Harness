# P06 detractor senior

Cycle: `C-010`
Role: simulated auditor, profile `detractor_senior`
Verdict: `pass_with_conditions`

## Findings before implementation

1. `packaging/runtime-layout.json` is required by its own integrity contract but
   is not classified as product. A payload produced from current rules can omit
   the authority used to validate it.
2. Directory-prefix classification is not an exact packaging allowlist. The
   structural manifest is 71 product/template files behind current P01-P05
   source, while it also contains 32 instance or source-only files.
3. P05 tag reconstruction inventories every tracked file. The `v0.16.0` tag
   contains an undeclared personal `infoHebriHarness.md`; packaged baselines
   must use each release manifest as authority and must not publish that path or
   its content hash.
4. The Codex-bundled `pwsh` and the developer installation of Node are not
   redistributable product inputs. Core can target the Windows PowerShell 5.1
   path after local behavior tests; MCP must remain optional and fail closed.
5. WiX 5.0.2 is present with local NuGet metadata declaring MS-RL, but no
   network-authoritative applicability review was approved. A local unsigned
   engineering candidate is not a distributable release decision.
6. A batch wrapper is avoidable and weak for argument preservation. The host
   already provides the .NET Framework 4.8 compiler and platform runtime, so a
   small launcher can derive its trusted root, validate hashes and forward
   arguments without searching CWD.

## Non-negotiable conditions

- Payload copies only exact manifest entries that also resolve to product or
  template; generated launcher/release/manifest files are added explicitly.
- Source absence, duplicate paths, reparse points, hash drift, personal paths or
  output inside source fail before publication.
- Builds are staged and published atomically under `artifacts/p06`; repeated
  payloads must have equivalent path/size/hash inventories.
- Launcher uses its executable location and the Windows system directory. It
  preserves streams and exit code, validates the payload before dispatch and
  never loads executable content from CWD.
- MSI is x64/per-machine and declarative. No custom actions, project discovery,
  migration, network, embedded credentials or source-tree paths.
- MSI installation, elevation, registry/PATH mutation, signing, clean/offline VM
  and real consumer use remain blocked under this approval.
- MCP source may remain in the product inventory, but absence of a verified Node
  runtime/dependency closure returns `OPTIONAL_FEATURE_MISSING`; it is not PASS.
- Reviewer executes behavior and artifact inspection, not only source regexes.

These conditions bind P06-T01..T08 and must be repeated if packaging scope or
toolchain changes.
