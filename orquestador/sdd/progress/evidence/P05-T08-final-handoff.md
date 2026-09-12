# P05-T08 - Final handoff

Phase: P05 - reversible legacy migration and drift preservation.

Verdict: `accepted_local_with_pilot_packaging_and_host_blockers`.

## Verification matrix

| Oracle | PowerShell 7.6.5 | Windows PowerShell 5.1.26100.9444 |
|---|---|---|
| P05-V01 pure plan, personal-data privacy and pristine apply | PASS | PASS |
| P05-V02 explicit modified/unknown preservation | PASS | PASS |
| P05-V03 canonical conflict fail-closed | PASS | PASS |
| P05-V04 prior-backup exclusion and repeated migration | PASS | PASS |
| P05-V05 pre/post publication and catalog failures | PASS | PASS |
| P05-V06 post-change-aware restore | PASS | PASS |
| P05-V07 corrupt snapshot rejection before writes | PASS | PASS |
| P05-V08 space, containment, junction and occupied lock | PASS | PASS |
| Closed descriptor and fixture-only negative cases | PASS, 69 checks | PASS, 69 checks |
| Full local tag `v0.10.11` | PASS, 350 files | not_run |
| Full local tag `v0.16.0` | PASS, 404 files | not_run |
| Existing bound restore SHA-256 regression | PASS | PASS |
| Node/MCP `project_service` smoke, `-NoGit` | PASS | Same Node runtime |
| Aggregate `validate-harness -RunNegativeTests -NoGit` | PASS | PowerShell 7 aggregate |

Tag hashes:

- `v0.10.11`: `aff09fdc0cb9a63d30b0943f16ce2e72d6a50d6a0aee44ff89f9cd8ad9d8dffb`
- `v0.16.0`: `e6f2d26e50848fbdf5f169917c36f1718ba37f777dea5d6416e469c2e5f30ada`

Aggregate warnings: `leader_light` 3532/2600 and `runtime_reentry` 2623/1600;
both remain below hard limits 5200 and 3200. No warning was converted to PASS.

## Effective interface

- CLI: `scripts/hebrinex-central.ps1 migrate`, API `central1`.
- Service: `scripts/lib/legacy-migration-service.psm1`.
- MCP: `project_service` fields `baseline_path`, `decisions_path`,
  `snapshot_base`, `snapshot_path`, `restore` and preservation flag.
- Contracts: `orquestador/runtime/{schemas,templates}/legacy-migration-*`.
- Runbook: `orquestador/runtime/legacy-migration-central1.md`.

## Handoff

P06 must package the central CLI/service, schemas/templates, fixtures as
appropriate, validator and trusted baselines atomically. Source presence is not
installed-payload evidence. It must not make untested versions supported.

P08/P09 retain disposable-copy pilot, clean/offline VM, installed permissions,
process-termination recovery and independent release review. This P05 approval
does not authorize any consumer migration or backup deletion.
