# Evidence - P00-T03 CLI Baseline

```yaml
evidence_id: E-P00-T03-001
cycle_id: C-001
slice_id: P00-T03
agent_id: A-P00-I02
role: executor
profile: worker
declared_task_role: implementer
execution_mode: simulated
approval_id: P00-T03-EXEC-013
action_type: analysis_and_documentation
summary: "Capture the current stable CLI 0.5 behavior from implementation and tests."
result: pass_with_warnings
created_at: "2026-09-08"
```

## Scope and Sources

- Public entrypoint: `scripts/hebrinex.ps1`.
- Declared contract: `orquestador/method/cli-contract.md`, contract version `0.5`, status `stable`.
- Dedicated oracle: `scripts/validate-cli.ps1`.
- Runtime slash-command reference: `orquestador/runtime/commands.md`; this is a separate prompt/runtime interface, not the PowerShell CLI command set.
- Current root inspected: source template version `0.17.1`.
- No consumer, operational migration, bootstrap, restore, network or Git command was executed while capturing this baseline.

## Invocation and Global Parameters

The script exposes one positional command and a flat global parameter surface (`scripts/hebrinex.ps1:1-34`). Parameters are accepted by the script before command-specific validation.

| Parameter | Type/default | Commands observed using it | Status |
|---|---|---|---|
| `Command` | closed `ValidateSet`, default `help` | all | observed |
| `Root` | string, parent of `scripts` | all path-based commands | observed |
| `RunNegativeTests` | switch | `validate`, `audit` | observed |
| `CheckOnly`, `Apply` | switches | `approve`, `migrate`, `bootstrap`, `update-bound`, `list-bound-backups`, `restore-bound`, `command` | observed |
| `Acquire`, `Release`, `List` | switches | `lock` | observed |
| `TargetVersion` | string, default `0.17.1` | `migrate` | observed |
| `ProjectRoot` | empty string | `bootstrap`, `update-bound`, `list-bound-backups`, `restore-bound` | observed |
| `BackupId` | empty string | `restore-bound` | observed |
| `ApprovalId` | empty string | `preflight` display; `command` validation | observed |
| `Action`, `ReadSet`, `WriteSet`, `Risk`, `Verification` | strings; `Risk=bajo` | `preflight` display | observed |
| `CommandText`, `Purpose`, `RiskClass` | strings | `approve`, `command` | observed |
| `RoleId`, `Capability`, `FromState`, `ToState` | strings | `agent-runtime`; state pair also used by `state-machine` | observed |
| `TtlMinutes` | integer, default `60`; lock substitutes `120` when omitted | `approve`, `lock -Acquire` | observed |
| `Paths`, `LockId`, `Owner`, `Reason` | strings | `lock` | observed |
| `Json` | switch | `command`, `state-machine`, `agent-runtime` | observed |

The CLI has no command-specific parameter sets. Except for explicit branch checks, irrelevant global switches are not rejected by a common dispatcher. This is current behavior, not a recommendation.

## Closed Command Catalog (17/17)

| Command | Required inputs/mode | Output contract | Effect and implementation | Test status before T03 validation |
|---|---|---|---|---|
| `help` | none | `cli_contract_version=0.5`, `cli_status=stable`, closed command CSV | read-only; `Show-Help` at `scripts/hebrinex.ps1:1385-1410` | dynamically covered by `validate-cli.ps1:140-147` |
| `status` | optional `-Root` | root/version/binding/state/approval/locks plus `runtime_authority=non_authoritative` | reads binding, state, version and lock inventory (`scripts/hebrinex.ps1:1418-1438`) | dynamically covered at `validate-cli.ps1:149-152` |
| `budget` | optional `-Root` | six named `used/max hard status` lines | read-only token estimate (`scripts/hebrinex.ps1:1440-1449`) | dynamically covered at `validate-cli.ps1:154-157` |
| `usage` | optional `-Root` | kernel/docs/full-tree/profile metrics and `writes=false` | read-only chars/4 report (`scripts/hebrinex.ps1:220-249,1450-1452`) | dynamically covered at `validate-cli.ps1:159-176` |
| `preflight` | fields are optional in code | labeled preflight and `Requiere SI: SI` | display only; no field validation or envelope write (`scripts/hebrinex.ps1:1453-1465`) | dynamically covered at `validate-cli.ps1:179-183` |
| `approve` | exactly one of `-CheckOnly|-Apply`; nonempty `-CommandText` | CheckOnly markers or generated `APR-*`, path, expiry, hash, `writes=true` | Apply writes approval envelope through `New-HebriApprovalEnvelope` (`scripts/hebrinex.ps1:1466-1494`) | CheckOnly/Apply/invalid dynamically covered at `validate-cli.ps1:188-209`; test deletes its envelope |
| `validate` | optional `-RunNegativeTests` | nested validator output; exit propagated | runs `validate-harness.ps1` (`scripts/hebrinex.ps1:1496-1501`); validators may create temporary fixtures | dispatcher only statically inspected before T03 |
| `audit` | optional `-RunNegativeTests` | nested audit output; exit propagated | runs `audit-harness.ps1` (`scripts/hebrinex.ps1:1502-1507`); aggregate validators may create temporaries | dispatcher only statically inspected before T03 |
| `migrate` | exactly one `-CheckOnly|-Apply`; optional target | CheckOnly no-op markers or delegated migration output | same-version CheckOnly is read-only; other cases delegate to `migrate-harness.ps1` (`scripts/hebrinex.ps1:1508-1537`) | same-version CheckOnly and conflicting mode covered at `validate-cli.ps1:185-186,288`; Apply not run here |
| `bootstrap` | exactly one mode; Apply needs `-ProjectRoot` | CheckOnly plan or applied paths/counts/report and `bootstrap_status=applied` | Apply creates bound tree, backup, binding/state/contract/report and `.gitignore` entry (`scripts/hebrinex.ps1:1315-1356,1539-1560`) | mode/markers statically asserted; operational Apply not run by dedicated CLI test |
| `update-bound` | exactly one mode; target project | CheckOnly plan or version/copy/preserve/backup/report and `update_status=applied` | Apply backs up, copies payload, canonicalizes instance data and validates (`scripts/hebrinex.ps1:888-959,1562-1586`) | mode/markers statically asserted; operational Apply not run by dedicated CLI test |
| `list-bound-backups` | only `-CheckOnly`; target project | target/binding, backup counts and per-backup metadata, `inventory_status=ok` | read-only inventory (`scripts/hebrinex.ps1:1095-1130,1588-1593`) | invalid Apply dynamically covered at `validate-cli.ps1:287`; positive target case not run there |
| `restore-bound` | exactly one mode; target project and backup ID for useful operation | CheckOnly plan or restored count/pre-backup/report and `restore_status=applied` | Apply makes pre-restore backup, restores manifest files and validates (`scripts/hebrinex.ps1:1209-1277,1594-1615`) | mode/markers statically asserted; operational Apply not run by dedicated CLI test |
| `command` | exactly one mode; command text; optional approval/risk/json | gateway key/value or JSON schema `hebrinex.command_gateway.result` v0.4 | delegates to `command-gateway.ps1`; CheckOnly does not execute; Apply is gateway-controlled (`scripts/hebrinex.ps1:1679-1685`) | CheckOnly JSON, valid/fake approval and missing mode covered at `validate-cli.ps1:199-222,286`; Apply execution not run |
| `state-machine` | from/to states; optional JSON | schema `hebrinex.runtime.state_machine.decision` | read-only delegated lifecycle decision (`scripts/hebrinex.ps1:1617-1621`) | allow and invalid transition covered at `validate-cli.ps1:224-234,284` |
| `agent-runtime` | role/capability; optional transition/JSON | schema `hebrinex.runtime.agent_enforcement.decision` | read-only delegated capability decision (`scripts/hebrinex.ps1:1622-1626`) | allow and reviewer-deny covered at `validate-cli.ps1:236-245,285` |
| `lock` | exactly one `-Acquire|-Release|-List`; paths or lock ID as applicable | list counts; acquire/release identifiers and `lock_status` | List reads; Acquire writes lock; Release rewrites status (`scripts/hebrinex.ps1:1627-1677`) | acquire/list/conflict/release/reacquire and errors covered at `validate-cli.ps1:248-282`; test removes roundtrip files |

## Exit and Error Behavior

- Successful local branches end with implicit process exit `0`.
- Delegated `validate`, `audit`, `migrate`, `command`, `state-machine` and `agent-runtime` propagate a nonzero `$LASTEXITCODE` (`scripts/hebrinex.ps1:1496-1537,1617-1626,1679-1685`).
- Contract violations use `throw`; the process is nonzero, but no stable numeric error-code taxonomy is documented.
- Semantic failure is primarily communicated by text markers or the delegated JSON `decision/reason` fields.
- Exact exception text is asserted for several mode and capability negatives in `scripts/validate-cli.ps1:209,279-288`.

## stable0.5 Compatibility Oracle

Compatibility requires all of the following to remain aligned:

1. `ValidateSet` contains exactly the public names expected by the validator (`scripts/hebrinex.ps1:1-4`; `scripts/validate-cli.ps1:8,126-133`).
2. `help` preserves version, stable status and command CSV markers (`scripts/hebrinex.ps1:1385-1389`; `scripts/validate-cli.ps1:111-114,140-147`).
3. `orquestador/method/cli-contract.md:9-95` preserves command, output, mode and safety semantics.
4. `scripts/validate-cli.ps1` preserves static assertions, positive calls, negative calls and temporary cleanup.
5. The dedicated validator stays wired into audit, CI, initialization and aggregate validation (`scripts/audit-harness.ps1:36`; `.github/workflows/ci.yml:36`; `init.sh:199`; `scripts/validate-harness.ps1:607`).

Changing only the help CSV, only the contract document or only the implementation is incompatible with this oracle.

## Explicit Gaps and Doubts

1. **C01 (`observed`)**: `validate-cli.ps1` does not positively invoke the public `validate`, `audit`, `bootstrap`, `update-bound`, `list-bound-backups` or `restore-bound` dispatcher paths. Other dedicated validators may exercise underlying services, but that is not equivalent to complete CLI dispatch coverage.
2. **C02 (`observed`)**: operational `migrate -Apply`, `bootstrap -Apply`, `update-bound -Apply`, `restore-bound -Apply` and `lock -Acquire|-Release` do not receive or validate `-ApprovalId` in their dispatcher branches. Approval may be enforced externally by operating procedure, but is not proven by this CLI baseline.
3. **C03 (`observed`)**: `preflight` formats supplied strings and always prints `Requiere SI: SI`; it does not reject missing ID/read-set/write-set/verification.
4. **C04 (`observed`)**: global parameters are not modeled as command-specific PowerShell parameter sets, so irrelevant switches can be accepted unless a branch explicitly rejects them.
5. **C05 (`observed`)**: no stable numeric exit-code taxonomy exists beyond success/nonzero and delegated codes.
6. **C06 (`observed`)**: `orquestador/runtime/commands.md` defines eight `/harness ...` commands with different semantics. They must not be conflated with the 17-command PowerShell CLI.
7. **C07 (`not_run`)**: no live installed `InstallRoot/ProjectRoot/InstanceRoot` layout, MSI launcher or central registry CLI behavior exists in this baseline; those are future-phase subjects.

## Validation Plan and Cleanup Contract

- Run `scripts/validate-cli.ps1 -RunNegativeTests` as the direct stable0.5 oracle.
- Run `scripts/validate-harness.ps1 -RunNegativeTests` as aggregate regression coverage.
- The direct validator intentionally creates one temporary approval envelope and two lock files, then deletes them (`scripts/validate-cli.ps1:192-205,248-274`). Verify no new approval or lock remains.
- Parse migration state and cycle audit JSONL, run `git diff --check`, and preserve unrelated `.claude/settings.local.json` without reading or changing it.

## Executed Validation

- CLI catalog coverage check: pass, 17/17 public commands present.
- `scripts/validate-cli.ps1 -RunNegativeTests`: pass, `Stable CLI validation OK`.
- Approval/lock cleanup: pass; before and after the direct validator, approvals contained only `_README.md` plus historical `APR-20260706T013227Z-d20ab0.yaml`, and locks contained only `_README.md`.
- `scripts/validate-harness.ps1 -RunNegativeTests`: pass; release, CLI, bootstrap, bound update/backups/restore, agents, security, migration, fixtures, gateway, state machine and agent runtime validators passed.
- Context warnings: `leader_light 3786/2600` with hard limit 5200; `runtime_reentry 2876/1600` with hard limit 3200.
- Installed central layout, MSI lifecycle and operational consumer Apply runs remain `not_run`.

## Handoff

After validation, P00-T03 closes and P00-T04 becomes next: an auditor evaluates on-demand service versus daemon, databases and dependencies without implementing either option.
