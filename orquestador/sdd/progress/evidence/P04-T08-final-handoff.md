# P04-T08 - Final handoff

Phase: P04 - CLI, binding and recoverable catalog.

Verdict: `accepted_with_future_packaging_and_host_blockers`.

## Verification matrix

| Oracle | PowerShell 7.6.5 | Windows PowerShell 5.1.26100.9444 |
|---|---|---|
| P04-V01 two isolated lightweight projects | PASS | PASS |
| P04-V02 idempotence and contradictory binding | PASS | PASS |
| P04-V03 catalog failure and pending recovery | PASS | PASS |
| P04-V04 move, duplicate and copy-as-new | PASS | PASS |
| P04-V05 corrupt/deleted catalog and approved rebuild | PASS | PASS |
| P04-V06 pure status/list/doctor | PASS | PASS |
| P04-V07 unbind preservation and central hook resolution | PASS | PASS |
| Closed plan grammar, mixed identity and concurrent edit negatives | PASS | PASS |
| `validate-project-service.ps1 -RunNegativeTests` | PASS, 63 checks | PASS, 63 checks |
| Node 22.16 syntax + MCP smoke without Git | PASS | Same Node runtime |
| Aggregate `validate-harness.ps1 -RunNegativeTests -NoGit` | PASS | PowerShell 7 aggregate |

Aggregate warnings: `leader_light` 3495/2600 and `runtime_reentry` 2586/1600;
both remain below hard limits (5200 and 3200). No fixture residue remained.

## Effective interface

- CLI: `scripts/hebrinex-central.ps1`, `cli_api: central1`.
- Service: `scripts/lib/project-service.psm1`.
- MCP: `project_service`, with explicit project/catalog roots and role guard on
  approve/Apply.
- Schemas/templates: `orquestador/runtime/{schemas,templates}/project-*`.
- Operator runbook: `orquestador/runtime/project-service-central1.md`.
- Legacy oracle: `scripts/hebrinex.ps1`, unchanged.

## Failure semantics

Catalog failure after local identity commit is not success: `status: failed`,
`reason: REGISTRATION_PENDING`, `exit_code: 8`, `writes_performed: true`.
The next allowed action is a newly planned and separately approved `reconcile`.
Queries never repair implicitly.

## Handoff

P05 receives binding schema v1, `central1`, explicit errors and a non-fictitious
`migrate` placeholder. It must convert legacy data without creating dual authority.

P06 receives the exact central hook contract and source artifacts. It must add
them atomically to the payload/manifest, implement the trusted launcher and prove
installed discovery; P04 source presence is not installed-package evidence.

P08/P09 retain clean/offline VM, ACL, symlink-capable host, full provider
benchmark and release-grade independent review. None is represented as P04 PASS.
