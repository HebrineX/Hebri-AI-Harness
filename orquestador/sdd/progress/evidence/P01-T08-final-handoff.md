# P01-T08 - Final handoff

Phase: P01 - Layout and portable root resolution.

Approval: `P01-COMPLETE-020`; runtime envelope `APR-20260909T133916Z-fdf13c`.

Verdict: `accepted_with_open_platform_and_future_integration_blockers`.

## Delivered interface

- Contract `1.0.0`, runtime API line `1`.
- Executable deny-by-default layout with 90 classified rules.
- Versioned context, request, result and layout schemas.
- PowerShell context, installation and resource resolvers in the existing common module.
- Separate read/write semantics with no creation during resolution.
- Segment containment, ADS/provider/traversal rejection and reparse checks.
- Explicit source, legacy and central modes with no central-to-legacy fallback.
- Strict binding conflict/injection rejection.
- Language-neutral fixtures and a validator integrated into aggregate validation.
- `SHARED_MANIFEST.yaml` retained as a validator-proven legacy projection of the central layout.

The stable CLI contract was not redefined. Existing legacy functions were retained, and existing CLI/MCP consumers were not migrated in P01.

## Verification summary

- P01-V01: PASS, including all 90 layout rules and two-project isolation.
- P01-V02: PASS; missing read differs from destination preparation and no file is created.
- P01-V03: PASS; traversal, absolute path, ADS, provider, unknown resource and similar-prefix context are rejected.
- P01-V04: junction PASS; real symlink creation BLOCKED by host privilege and not represented as PASS.
- P01-V05: PASS against prior legacy behavior; central mode never falls back.
- P01-V06: PASS for corrupt layout, injected binding, untouched witness and dual-binding conflict.
- PowerShell 7.6.5: PASS.
- Windows PowerShell 5.1.26100.9444: PASS.
- Aggregate harness validation with negatives: PASS.
- Temporary fixture residue: none.

## Open blockers and ownership

- P01-B04: repeat the real symlink oracle on a clean VM or Developer Mode host before release acceptance.
- P03/P04: replace MCP/CLI local maps with the published resolver contract and fixtures.
- P04/P05: create/migrate real central bindings and catalogs only with project-specific approval.
- P06: add central artifacts to the structural payload manifest and implement trusted Windows installed-product discovery.
- P06/P07: payload hashes/signing, installer, upgrade/repair and registry ownership remain unimplemented.

These blockers do not silently expand P01. They prevent claiming an installed or fully integrated central product.

## Rollback

Remove the new central API block, layout, schemas, fixtures and validator integration; restore `SHARED_MANIFEST.yaml` and tracking files. Do not alter legacy instance data. No external system rollback is needed because P01 performed no install, registry, project migration, Git, network or consumer effect.

## Handoff

P02 receives the accepted resolver boundary and must place approvals/state/isolation semantics on top of it without creating a second path map. P03/P04 consume the same contract later. The next phase must read this report, the P01 gate log and `packaging/runtime-layout.json` before implementation.
