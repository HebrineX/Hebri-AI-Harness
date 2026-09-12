# P06-T08 - Final handoff

Phase: P06 - payload, launcher and MSI candidate.

Verdict: `implemented_local_candidate_with_installation_and_mcp_present_blockers`.

## Reconstructible candidate

Run `scripts/validate-packaging.ps1` in PowerShell 7 on a Windows x64 build
host with the pinned local toolchain. It creates and validates only
`artifacts/p06/`:

- `payload-core/payload-manifest.json`: SHA-256
  `fe0bc3504c69c33ec49119a131663338dbade2c25ea85f3790b802e7bea4fc00`.
- `payload-core/bin/hebrinex.exe`: SHA-256
  `4c97f47936a3f5f5349a274e6ad27165aacb03646429df84b11058415c739697`.
- `Hebri-AI-Harness-0.17.1-x64.msi`: SHA-256
  `7c836b9bc639f2cd7ae533dee310c268e2bfeda5eea87bbfc831c963f9f58aa0`.
- `validation-report.json`: 43 checks, no failures, ICE PASS.
- `validate-harness-ps7.log` and `validate-harness-ps5.log`: aggregate PASS.

The installer identity is ProductCode
`{E6639B49-CC2C-5B2C-BE31-5225B7A7852A}` and UpgradeCode
`{5E6C72A1-831B-49CE-B25F-21D930A77101}`. P07 must use these exact identities
and the candidate hash when designing upgrade, repair and uninstall.

## P07 entry conditions

- Do not install this MSI on the development host or a real consumer.
- Prepare a separate preflight for a disposable Windows VM/snapshot, elevation,
  MSI logging, filesystem/registry/PATH snapshots and cleanup.
- Build a second compatible version with a different ProductCode before testing
  major upgrade; keep the UpgradeCode stable.
- Test repair and uninstall ownership without deleting `.hebrinex`, catalog,
  project data, evidence or backups.
- Keep MCP unavailable unless a separate dependency/license/offline decision
  adds a verified central Node payload.
- Preserve the distinction between reproducible payload content and currently
  non-identical MSI bytes.

P06 authoring and local verification are complete. P06 installation acceptance
is not complete and remains a P07/P08 gate.
