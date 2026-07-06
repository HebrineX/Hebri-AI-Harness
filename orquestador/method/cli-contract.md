# CLI Contract

Version: 0.16.0
Contract version: 0.5
Status: stable

`scripts/hebrinex.ps1` is the stable public CLI for Hebri-AI-Harness. It is a thin operational entrypoint: it exposes status, budgets, preflight envelopes, validators, migration/bootstrap flows, the Command Gateway, state-machine checks and agent-runtime enforcement, but it does not replace `state.yaml`, `registry.yaml`, gates, approvals, evidence or agent contracts.

## Stable Commands

The public command set for contract version `0.5` is closed:

- `help`
- `status`
- `budget`
- `usage`
- `preflight`
- `approve`
- `validate`
- `audit`
- `migrate`
- `bootstrap`
- `update-bound`
- `list-bound-backups`
- `restore-bound`
- `command`
- `state-machine`
- `agent-runtime`
- `lock`

A command outside this list is not part of the public CLI contract.

## Output Contract

`help` must emit parseable markers:

```text
cli_contract_version=0.5
cli_status=stable
commands=help,status,budget,usage,preflight,approve,validate,audit,migrate,bootstrap,update-bound,list-bound-backups,restore-bound,command,state-machine,agent-runtime,lock
```

Operational commands must keep parseable `key=value` lines or machine-readable JSON for validators and automation. Human prose can be added around those lines only when it does not remove or rename contract markers.

Required markers:

- `status`: `harness_version`, `binding_mode`, `project_root`, `runtime_authority=non_authoritative`.
- `budget`: `memory_bootstrap`, `first_message`, `debug_log_intake`, `leader_light`, `runtime_status`, `runtime_reentry`.
- `usage`: `kernel_tokens=`, `docs_tree_tokens=`, `savings_docs_pct=` (entero redondeado; denominador del claim del README: `AGENTS.md` + `orquestador/method/` + `prompts/` segun manifest), `full_tree_tokens=`, `savings_pct=` (frente al arbol completo del manifest; metrica para la poda), una linea `profile_<name>_tokens=` por perfil de `context-budget.yaml` y `writes=false`. Read-only; mide con el mismo metodo chars/4 que `budget`.
- `preflight`: `Approval ID`, `Read-set`, `Write-set`, `Riesgo`, `Verificacion`, `Requiere SI: SI`.
- `migrate -CheckOnly`: `writes=false` when no migration write is performed.
- `bootstrap -CheckOnly`: `writes=false`, `apply_available=true`, `requires_project_root=true`.
- `update-bound -CheckOnly`: `writes=false`, `apply_available=true`, `requires_project_root=true`.
- `list-bound-backups -CheckOnly`: `writes=false`, `apply_available=false`, `requires_project_root=true`.
- `restore-bound -CheckOnly`: `writes=false`, `apply_available=true`, `requires_project_root=true`.
- `approve -CheckOnly`: `writes=false`, `apply_available=true`.
- `approve -Apply`: `approval_id`, `approval_path`, `expires_at`, `command_sha256`, `writes=true`.
- `command -Json`: JSON schema `hebrinex.command_gateway.result`.
- `state-machine -Json`: JSON schema `hebrinex.runtime.state_machine.decision`.
- `agent-runtime -Json`: JSON schema `hebrinex.runtime.agent_enforcement.decision`.
- `lock -Acquire`: `lock_id=L-...`, `lock_path`, `owner`, `expires_at`, `paths`, `writes=true`, `lock_status=acquired`.
- `lock -Release`: `lock_id`, `previous_status`, `writes=true`, `lock_status=released`.
- `lock -List`: `writes=false`, `active_locks=`, `expired_locks=`, one `lock_id=... lock_state=...` line per lock.

## Mode Rules

Mode-bearing commands require exactly one execution mode:

- `migrate` requires exactly one of `-CheckOnly` or `-Apply`.
- `bootstrap` requires exactly one of `-CheckOnly` or `-Apply`.
- `update-bound` requires exactly one of `-CheckOnly` or `-Apply`.
- `restore-bound` requires exactly one of `-CheckOnly` or `-Apply`.
- `command` requires exactly one of `-CheckOnly` or `-Apply`.
- `approve` requires exactly one of `-CheckOnly` or `-Apply`.
- `lock` requires exactly one of `-Acquire`, `-Release` or `-List`.

`list-bound-backups` is inventory-only and supports only `-CheckOnly`.

Read-only commands (`help`, `status`, `budget`, `usage`, `preflight`, `state-machine`, `agent-runtime`) must not write files. `validate` and `audit` may run validators but must not declare operational work complete by themselves.

## Safety Contract

The CLI is not an agent and does not define agent authority. Agent definitions remain harness-governed by YAML contracts under `orquestador/agents/`.

Security-sensitive actions keep deny-by-default behavior:

- `approve -Apply` materializes one operator `SI` as an approval envelope in `orquestador/sdd/progress/approvals/` with expiry and an exact action hash; it approves only that exact command text.
- `command` with `-ApprovalId` validates the envelope against the approval store; missing, expired, unapproved or mismatched envelopes block the call.
- `command -CheckOnly` classifies and reports; it does not execute the command text.
- `command -Apply` delegates to the Command Gateway and executes only strict read-only allowlisted plans.
- `state-machine` reads lifecycle contracts and blocks invalid transitions.
- `agent-runtime` reads agent/capability contracts and blocks missing or denied capabilities.
- `lock -Acquire` writes an exclusive `L-*.lock.md` under `orquestador/sdd/progress/locks/` with owner, paths and TTL (`-TtlMinutes`, default 120); any overlap with an active non-expired lock fails with `lock_conflict`. `lock -Release` marks the lock `released`; `lock -List` is read-only inventory.
- `bootstrap`, `update-bound` and `restore-bound` require `Apply` plus their dedicated backup/preservation validators before reporting applied status.
- Git remote operations are not part of the CLI stable execution surface.

## Validation

`scripts/validate-cli.ps1` is the dedicated contract validator. It must be invoked by:

- `scripts/validate-harness.ps1`
- `scripts/audit-harness.ps1`
- `init.sh`
- `.github/workflows/ci.yml`

A release is not usable if the CLI contract validator is missing or failing.
