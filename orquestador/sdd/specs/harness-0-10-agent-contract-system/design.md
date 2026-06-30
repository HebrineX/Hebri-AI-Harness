# Design - Harness 0.10.0 Agent Contract System

## Status

This document designs a future 0.10.0 architecture. The stable harness remains
0.9.0. This design is not a release boundary and not runtime authority.

Prior local 0.10.0 spikes can be used as reference evidence only. The source
of truth for 0.10.0 becomes the reviewed spec, then the later approved runtime
changes that implement it.

## Design principle

```text
An agent does not exist because a prompt says so.
An agent exists only when the harness owns a registry entry, a role contract,
a security profile, a lifecycle rule and a valid handoff path.
```

The harness is the authority layer. Agents are governed execution units. The
IA can request work, propose candidate text and report evidence, but it cannot
create operational authority for itself.

## Hard Lock 0 - Agent authority

0.10.0 should introduce `HL0_agent_authority`:

```text
Ninguna IA define agentes, roles, permisos ni escalaciones.
Solo el harness puede definir contratos de agente.
```

Operational role requests should be resolved through the harness:

```text
Rol solicitado: implementer
Contrato harness: orquestador/agents/role-contracts/implementer.yaml
Estado: instanciable | bloqueado
Motivo:
```

If the registry or contract is missing:

```text
Bloqueado: el harness no define ese agente.
```

`agents/*.md` may remain as human documentation and onboarding material, but
it must not be canonical authority for runtime role definition.

## Proposed file tree

The future runtime tree is proposed as additive:

```text
orquestador/
  agents/
    agent-registry.yaml
    capability-registry.yaml
    lifecycle-registry.yaml
    model-adapter-profiles.yaml
    role-contracts/
      leader.yaml
      implementer.yaml
      reviewer.yaml
      auditor.yaml
      reporter.yaml
      spec-author.yaml
      worker.yaml
    security-profiles/
      read-only.yaml
      write-scoped.yaml
      reviewer-readonly.yaml
      auditor-blocking.yaml
      release-manager.yaml
    handoff-contracts/
      leader-to-implementer.yaml
      implementer-to-reviewer.yaml
      reviewer-to-leader.yaml
      auditor-to-leader.yaml
      reporter-to-human.yaml
    runtime-profiles/
      leader-runtime.yaml
      implementer-runtime.yaml
      reviewer-runtime.yaml
      auditor-runtime.yaml
      reporter-runtime.yaml
    context-packs/
    tool-packs/
    playbooks/
    failure-modes/
    evaluation-rubrics/

  security/
    threat-model.yaml
    permission-registry.yaml
    command-risk-registry.yaml
    write-scope-registry.yaml
    network-policy.yaml
    secrets-policy.yaml
    escalation-policy.yaml
    logging-policy.yaml
    supply-chain-policy.yaml

  migration/
    migration-registry.yaml
    versions/
      0.9.0-to-0.10.0.yaml
      0.8.10-to-0.10.0.yaml
    contracts/
      post-migration-contract.yaml
    reports/
      migration-report.template.yaml

scripts/
  validate-agent-contracts.ps1
  validate-security-policy.ps1
  validate-migration.ps1
  audit-harness.ps1
  migrate-harness.ps1
```

None of these files should be created as runtime authority until an
implementation approval exists.

## Authority model

The future `agent-registry.yaml` should declare:

```yaml
schema: hebrinex.agent_registry
version: "0.1"
harness_version: "0.10.0"
authority:
  agent_definition_authority: harness_only
  runtime_instantiation: harness_controlled
  ai_may_define_agents: false
  ai_may_modify_agent_contracts: false
  ai_may_escalate_capabilities: false
  prompt_may_define_roles: false
roles:
  - id: leader
    contract: orquestador/agents/role-contracts/leader.yaml
    lifecycle: governed
  - id: implementer
    contract: orquestador/agents/role-contracts/implementer.yaml
    lifecycle: governed
  - id: reviewer
    contract: orquestador/agents/role-contracts/reviewer.yaml
    lifecycle: governed
```

Rules:

- if the role is not in `agent-registry.yaml`, it does not exist;
- if the role contract file is missing, the role cannot instantiate;
- if the security profile is missing, the role cannot instantiate;
- if the requested capability is absent, the action blocks;
- if a prompt contradicts the registry, the registry wins;
- if `agents/*.md` contradicts the registry, the registry wins;
- if chat memory contradicts persisted contract state, persisted state wins.

## Role contract shape

Each role contract should be explicit and small:

```yaml
schema: hebrinex.agent_role_contract
version: "0.1"
id: implementer
role_type: execution
purpose: "Produce scoped changes after approval."
authority:
  may_define_agents: false
  may_approve_work: false
  may_review_own_work: false
security_profile: write-scoped
capabilities:
  allow:
    - read_declared_files
    - edit_approved_write_set
    - run_local_validation
  deny:
    - approve_work
    - review_own_work
    - define_agent
    - edit_security_policy
    - git_push
    - network
    - secrets_access
requires:
  preflight: true
  approval_id: true
  write_set: true
  active_lock: true
  ownership: true
  evidence: true
handoff:
  contract: orquestador/agents/handoff-contracts/implementer-to-reviewer.yaml
closure:
  required: true
  before_done: true
```

The leader contract should coordinate, assign, gate and close. It should not
write product changes. The reviewer contract should read, assess and block or
approve. It should not edit. The auditor contract should challenge evidence,
scope, security and design risk. It should not implement.

## Capability model

`capability-registry.yaml` should map action names to risk and required gates:

```yaml
schema: hebrinex.capability_registry
version: "0.1"
capabilities:
  read_declared_files:
    effect: none
    requires_preflight: false
  edit_approved_write_set:
    effect: write
    requires_preflight: true
    requires_lock: true
    requires_write_scope: true
  run_local_validation:
    effect: local_command
    requires_preflight: true
  use_network:
    effect: external
    requires_preflight: true
    requires_human_si: true
  git_remote_write:
    effect: external
    requires_preflight: true
    requires_human_si: true
```

The capability layer answers what the role may request. The security layer
answers whether that request is safe in the current context.

## Agent Runtime Enablement

0.10.0 should make every governed agent self-sufficient for its role. Security
alone is not enough: a safe agent can still be ineffective if it lacks mission,
context, workflow, tools, output contract and quality gates.

Principle:

```text
An agent is contract + context + tools + operating loop + validation + closure.
```

The harness cannot make a weak model reason like a stronger model. It can,
however, reduce ambiguity, bound the task, provide the right context, expose
safe tools, require structured self-review, trigger escalation and validate the
output before handoff.

### Runtime profile shape

Each role should have a runtime profile:

```yaml
schema: hebrinex.agent_runtime_profile
version: "0.1"
id: implementer-runtime
role_id: implementer
mission: "Produce scoped changes that satisfy an approved task."
operating_loop:
  - reconstruct_contract
  - inspect_relevant_context
  - plan_small_slice
  - apply_scoped_change
  - run_validation
  - prepare_handoff
required_inputs:
  - approval_id
  - task_scope
  - write_set
  - acceptance_criteria
expected_outputs:
  - modified_files
  - validation_results
  - evidence_refs
  - handoff_summary
decision_policy:
  autonomy_level: bounded
  ask_when_scope_changes: true
  prefer_existing_patterns: true
validation_routine:
  self_review_checklist: implementer-self-review
  external_validator: role_quality_implementer
escalation_triggers:
  - missing_approval
  - write_scope_mismatch
  - failing_validator
  - ambiguous_requirement
stop_conditions:
  - security_policy_block
  - missing_contract
  - out_of_scope_write
```

### Context packs

Context packs define the minimum useful context for a role. They should prevent
both under-context and uncontrolled full-context loading.

```yaml
schema: hebrinex.context_pack
version: "0.1"
id: implementer-context
role_id: implementer
required_refs:
  - active_contract
  - task_scope
  - relevant_files
  - acceptance_criteria
denied_by_default:
  - complete_memory
  - infoHebri.md
  - secrets
load_strategy: minimal_then_expand_with_approval
```

### Tool packs

Tool packs expose role-appropriate tools while staying subordinate to
capabilities and AppSec policy.

```yaml
schema: hebrinex.tool_pack
version: "0.1"
id: reviewer-tools
role_id: reviewer
allow:
  - read_files
  - run_readonly_diff
  - run_validation
deny:
  - edit_files
  - approve_own_work
  - git_push
  - network
constraints:
  inherits_capability_registry: true
  inherits_security_policy: true
```

### Playbooks and failure modes

Playbooks should encode role-specific operating practice:

- what to inspect first;
- how to decide whether scope is clear;
- what evidence to require;
- what output format to use;
- what anti-patterns to avoid;
- when to stop and escalate.

Failure modes should define common failure patterns per role, for example:

- implementer edits outside write-set;
- reviewer proposes direct edits instead of findings;
- leader implements;
- auditor blocks without evidence;
- reporter changes verdict while summarizing.

### Model adapter profiles

`model-adapter-profiles.yaml` should let the harness adapt to weaker or more
limited AI providers:

```yaml
schema: hebrinex.model_adapter_profiles
version: "0.1"
profiles:
  simple_model:
    autonomy_level: low
    max_task_span: single_file_or_small_slice
    require_stepwise_checklist: true
    require_external_validation: true
    escalation_threshold: low
    context_strategy: narrow_explicit
  strong_model:
    autonomy_level: bounded
    max_task_span: multi_file_slice
    require_stepwise_checklist: true
    require_external_validation: true
    escalation_threshold: normal
    context_strategy: profile_based
```

This allows the harness to route the same role contract through different
runtime constraints without letting the model define its own authority.

### Agent quality evaluators

Each role should have an evaluation rubric:

```yaml
schema: hebrinex.agent_evaluation_rubric
version: "0.1"
id: reviewer-quality
role_id: reviewer
checks:
  - finding_has_file_reference
  - severity_is_justified
  - no_direct_edits
  - tests_or_validation_gap_reported
  - no_unverified_claims
minimum_result: pass
on_fail: block_handoff
```

Evaluators should be used before closure and before handoff. They do not
replace human approval; they make agent output more consistent and auditable.

## Security & AppSec model

Security in 0.10.0 is not only AI/harness permission safety. It must cover
application security for the harness as local software that reads files,
executes commands, migrates state and may interact with network/git/tools.

### Threat model

0.10.0 should explicitly model these actors and attack paths:

- trusted operator making approved changes;
- AI output that hallucinates authority or unsafe commands;
- malicious prompt content in repo files;
- untrusted repository or project input;
- malformed or malicious YAML;
- compromised dependency or downloaded script;
- accidental secret exposure through logs, reports or chat;
- local filesystem escape through path traversal or symlink resolution.

Primary surfaces:

- PowerShell and Bash scripts;
- migration service;
- YAML registries and contracts;
- prompt files and docs;
- git operations;
- network access;
- filesystem writes and backups;
- logs, reports and evidence files.

### Security registries

Security should be structured in these registries and policies:

- `permission-registry.yaml`: role to allowed/denied permissions.
- `command-risk-registry.yaml`: command classes, risk, effect and gates.
- `write-scope-registry.yaml`: allowed write roots, lock requirements and
  forbidden paths.
- `network-policy.yaml`: default deny, allowed exceptions and evidence.
- `secrets-policy.yaml`: default deny, redaction, storage and escalation.
- `escalation-policy.yaml`: when elevated privileges are permitted and how
  human `SI` must be recorded.
- `logging-policy.yaml`: evidence requirements, redaction rules and forbidden
  output.
- `supply-chain-policy.yaml`: dependency, download and remote-code rules.

Default stance:

```yaml
defaults:
  network: deny
  secrets_access: deny
  git_remote_write: deny
  destructive_filesystem: deny
  role_self_escalation: deny
  prompt_defined_permissions: deny
  downloaded_code_execution: deny
  secrets_in_logs: deny
```

Precedence:

```text
explicit_deny > missing_contract_block > missing_capability_block >
requires_preflight > allow_readonly
```

### Input and path validation

All future scripts should validate:

- project root and harness root resolve to expected locations;
- relative paths cannot escape with `..`;
- symlinks/junctions cannot escape approved roots;
- writes to `.git/`, shell profiles, home directories and unapproved temp
  paths are blocked;
- YAML files match expected schema before use;
- unknown keys either fail closed or are explicitly tolerated by schema.

### Command execution safety

`command-risk-registry.yaml` should classify commands as:

```text
read_only
local_validation
write
destructive
network
git_remote
secrets
privileged
```

Rules:

- prefer structured argument APIs over string-built shell commands;
- never turn untrusted YAML or prompt text directly into executable command
  strings;
- destructive, network, git remote, secrets and privileged commands require
  explicit capability, preflight, human `SI` and evidence;
- command output must pass redaction before becoming evidence or report text.

### Secrets management

`secrets-policy.yaml` should define:

- default deny for `.env`, keys, tokens, certificates and credential stores;
- sensitive-pattern detection for common token formats;
- redaction markers for logs and reports;
- prohibition on copying secret values into chat;
- explicit approval requirement for secret-bearing paths;
- failure mode when a secret is detected in output.

### Network and supply-chain safety

`network-policy.yaml` should require:

- default deny;
- allowlist by domain or endpoint;
- approved purpose;
- allowed method/tool;
- expiration or one-shot scope;
- evidence reference.

`supply-chain-policy.yaml` should require:

- no dependency install without approval;
- no remote script execution during migration;
- provenance for downloaded artifacts;
- lockfile/checksum use when available;
- explicit review before adding executable dependencies.

### Secure logging and backups

Logs, evidence and migration reports should be useful for audit without
exposing sensitive data:

- redact secrets before writing reports;
- record commands by intent and approved scope;
- include backup path, manifest/checksum and recovery instructions;
- fail closed if backup creation or verification fails;
- never treat chat memory as security evidence.

## Migration service design

The migration service should make version moves explicit, reversible and
verifiable.

Supported initial routes:

```text
0.9.0 -> 0.10.0
0.8.10 -> 0.10.0
```

Proposed CLI:

```powershell
.\scripts\migrate-harness.ps1 -Root .hebrinex -TargetVersion 0.10.0 -CheckOnly
.\scripts\migrate-harness.ps1 -Root .hebrinex -TargetVersion 0.10.0 -Apply
```

### Detect

Detect:

- source version;
- target version;
- binding mode;
- project root;
- harness path;
- local state files;
- active cycle;
- open locks;
- approvals;
- evidence paths;
- existing custom project memory.

### Plan

Plan:

- migration route file;
- files to add;
- files to preserve;
- files to merge;
- files to never overwrite;
- backup path;
- validators to run;
- expected post-migration contract.

`CheckOnly` stops here and writes nothing.

### Backup

`Apply` must create a backup before any write. The backup should contain enough
state to restore `.hebrinex/` if validation fails.

Backup evidence should include:

- source root;
- target backup path;
- created_at;
- file count;
- checksums or manifest;
- migration approval id.

### Apply

Apply should add 0.10.0 runtime files, merge registries and preserve local
state. It should never blindly replace:

- `PROJECT_BINDING.yaml`
- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- `orquestador/sdd/progress/cycles/`
- `orquestador/sdd/progress/locks/`
- `orquestador/sdd/progress/approvals/`
- `orquestador/memory/local/`
- `orquestador/memory/project/`
- evidence folders

### Validate

Validation should prove:

- agent contracts exist and are coherent;
- security policy is active and enforceable;
- migration report exists;
- backup exists;
- post-migration contract is active;
- `validate-harness.ps1` and `init.sh` agree with the new structure.

### Declare contract

The migration does not finish by copying files. It finishes when the active
contract says the new authority is applied and validators agree.

Expected post-migration contract shape:

```yaml
schema: hebrinex.post_migration_contract
version: "0.1"
harness_version: "0.10.0"
source_version: "0.9.0"
target_version: "0.10.0"
binding_mode: bound
project_root_verified: true
agent_authority: harness_only
agent_registry_active: true
security_policy_active: true
active_contract_written: true
old_approvals_expired: true
backup_verified: true
validators_passed: true
migration_status: applied
```

## Validators

### validate-agent-contracts.ps1

Responsibilities:

- verify `agent-registry.yaml` schema;
- verify each role contract exists;
- verify security profiles exist;
- verify runtime profiles, context packs, tool packs, playbooks and rubrics
  exist for instantiable roles;
- verify forbidden role combinations;
- fail if reviewer can write;
- fail if implementer can approve;
- fail if leader can implement;
- fail if prompts define operational roles outside registry.

### validate-security-policy.ps1

Responsibilities:

- verify permission registry;
- verify command risk classes;
- verify write scopes;
- verify network default deny;
- verify secrets default deny;
- verify escalations require explicit approval and evidence.
- verify input/path validation rules exist;
- verify secure logging and redaction policy exists;
- verify supply-chain policy blocks remote code execution by default.

### validate-migration.ps1

Responsibilities:

- verify route files;
- verify `CheckOnly` writes nothing;
- verify `Apply` requires backup;
- verify local state preservation rules;
- verify post-migration contract is active;
- fail if status is only declared.

### audit-harness.ps1

Responsibilities:

- run all validators;
- run negative tests when requested;
- emit one summary;
- return non-zero on any hard lock.

### validate-harness.ps1 and init.sh

Future 0.10.0 integration should call the new validators. If required
validators are missing, the harness should fail closed instead of treating
agent contracts as optional.

## What can break

- Existing prompts may contain role definitions that conflict with YAML
  contracts.
- Existing workflows may assume the chat can choose roles by convention.
- Project-specific approvals may need expiry or remapping during migration.
- Validation may expose previously implicit permissions as missing
  capabilities.
- Runtime enablement may require role definitions to become more explicit than
  current docs/prompts.
- Weak model profiles may reduce autonomy and require smaller task slices.
- Consumer projects with customized `.hebrinex/` files may need merge rules.
- AppSec validation may block previously accepted command patterns, network
  calls or filesystem writes.
- Secret redaction may make old evidence formats invalid.

## Risk controls

- Keep 0.10.0 additive until migration validation is proven.
- Preserve 0.9.0 authority files by default.
- Require backup before Apply.
- Require CheckOnly for preview.
- Require post-migration contract plus validators for success.
- Keep prompts subordinate to registries.
- Keep role separation hard-coded in contracts and validators.
- Treat runtime profiles as enablement, not authority escalation.
- Evaluate agent output before closure and handoff.
- Treat AppSec controls as fail-closed by default.
- Require negative tests for command injection, path traversal, symlink escape,
  secret leak, unsafe network, git remote abuse and backup failure.

## Open decisions

- Whether `agent-registry.yaml` should live under `orquestador/agents/` only,
  or whether a compatibility pointer should exist under root `agents/`.
- Whether `spec-author` is a first-class role or a scoped implementer profile.
- Whether security profiles belong under `orquestador/agents/` or only under
  `orquestador/security/`.
- How much prompt drift should be blocked in 0.10.0 versus warned first.
- Where backup archives should live for bound projects.
- Whether migration rollback is part of 0.10.0 or a later 0.10.x task.

## Future approval boundary

Moving from this spec to runtime work requires a new approval that names:

- branch or working tree policy;
- exact runtime files to create;
- exact scripts to add;
- validators to run;
- migration simulation targets;
- release/versioning decision;
- commit/push policy.
