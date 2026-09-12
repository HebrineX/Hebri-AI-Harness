# P02-T08 - Final handoff

Phase: P02 - State, approvals, isolation and recovery.

Approval: `P02-COMPLETE-021`; legacy runtime envelope `APR-20260909T150307Z-6dd2d0`.

Verdict: `accepted_with_future_host_and_packaging_blockers`.

## Delivered interface

- `operation-safety/1`, contract version `1.0.0`, implemented as an additive stdlib-only API in the existing common module.
- Canonical operation descriptor with project identity, resolved roots, exact write-set, plan/code hashes and approved preconditions.
- Scoped, expiring and consumable approval bound to descriptor/project/plan/roots/write-set/version.
- Atomic overlapping-resource locks with PID plus process-start identity; TTL never steals a lock.
- Canonical prepared/applying/committed/rolling_back/rolled_back/recovery_required journal.
- Same-volume atomic single-file publication with precondition revalidation, backup and durable result.
- Separately approved orphan recovery with deterministic hash checks and idempotent terminal result.
- Explicit central-mode guards on every inventoried PowerShell business writer.
- Versioned JSON schemas/templates, security policy updates and aggregate validator coverage.

## Reviewer findings resolved

1. Legacy approval risk was not forwarded by the CLI; fixed and dynamically validated.
2. Idempotent recovery returned an incomplete result; fixed to the full schema.
3. Recovery errors could remain `rolling_back`; fixed to persist `recovery_required` when possible.
4. Concurrent validator processes shared one fixture root; fixed with process-unique owned roots.
5. Caller-provided preconditions could differ from the approved descriptor; exact resource/hash binding added and adversarially tested.
6. Approval, lock and journal IDs were not fully cross-correlated and approval consumption was not operational; both were added and tested.

No reviewer finding remains open in the P02 implementation scope.

## Verification matrix

| Oracle | PowerShell 7.6.5 | Windows PowerShell 5.1.26100.9444 |
|---|---|---|
| P02-V01 overlapping real-process lock | PASS | PASS |
| P02-V02 separate-project isolation | PASS | PASS |
| P02-V03 fake/expired/consumed/foreign/changed/cross-bound approval rejection | PASS | PASS |
| P02-V04 five interruption boundaries and recovery | PASS, exit 91 | PASS, process termination observed with exit 0 |
| P02-V05 reused PID and approved recovery | PASS | PASS |
| P02-V06 concurrent edit and caller-hash bypass | PASS | PASS |
| P02-V07 repeated read-only inventory | PASS | PASS |
| Writer/schema contract checks | PASS | PASS |
| Full `validate-harness.ps1 -RunNegativeTests` | PASS | PASS |

Existing aggregate warnings remain below hard context limits. The P01 real-symlink oracle remains blocked by host privilege and is not represented as a P02 failure or pass. Temporary P02 fixture residue: none.

## Open blockers and ownership

- P02-B01 / P03-P04: installed CLI and MCP launchers must select `central_instance` from a verified binding and carry operation context end to end.
- P02-B02 / P06: package the new schemas, templates, validator and runtime code through the executable manifest.
- P02-B03 / P06-P08: protect approval/lock/journal stores with installed-host ACLs and validate on clean/offline hosts.
- P01-B04 / P08: repeat the real symlink oracle on a host with symlink capability.

These blockers prevent claiming a distributed, installed or fully integrated central product. They do not invalidate the source-level P02 contract and adversarial runtime proof.

## Project impact

Before P02, callers could rely mainly on procedural approval and legacy Markdown locks. After P02, central-mode writers can fail closed on a machine-readable chain: resolved project context -> descriptor -> human-scoped approval -> atomic lock -> journal -> result/recovery. Concurrent edits and interrupted processes are surfaced instead of silently overwritten or reported as success.

Source and legacy behavior remains compatible by explicit mode. The project does not yet activate central enforcement automatically because that would cross P03/P04/P06 ownership.

## Rollback

Remove the additive operation-safety block, P02 schemas/templates/fixtures/validator, writer guard parameters/calls, security-policy deltas and P02 tracking. Preserve all pre-existing instance data and never delete journals or backups from a real consumer as part of code rollback. No external rollback is required because P02 performed no install, network, Git or real consumer effect.

## Handoff

P03 receives the accepted runtime safety boundary and must integrate agent/provider dispatch without inventing a second approval or lock model. It must begin by reading this handoff, the C-004 gate log, the P01 resolver handoff and the operation schemas. Any P03 effect requires its own exact preflight and approval.
