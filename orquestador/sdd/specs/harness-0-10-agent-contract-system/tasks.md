# Tasks - Harness 0.10.0 Agent Contract System

## Status

These tasks describe future implementation work. They do not mark 0.10.0 as
ready and do not authorize runtime changes by themselves.

## Phase 0 - Spec hardening

- [ ] T0.1 Review this spec against 0.9.0 harness behavior.
  - Covers: R1, R24.
- [ ] T0.2 Confirm 0.10.0 remains design-only until a new approval exists.
  - Covers: R24.
- [ ] T0.3 Record open decisions before runtime files are created.
  - Covers: R25.
- [ ] T0.4 Decide whether work happens on a branch, local spike or release
  slice.
  - Covers: R25.

## Phase 1 - Baseline audit before runtime work

- [ ] T1.1 Run existing 0.9.0 validators as baseline:
  `validate-harness.ps1 -RunNegativeTests`, `validate-drift.ps1`,
  `check-adapter-drift.ps1` and `init.sh`.
  - Covers: R22, R24.
- [ ] T1.2 Inventory current role definitions in `agents/`, `prompts/roles/`,
  `orquestador/method/roles.md`, `agent-role-taxonomy.md` and
  `multiagent-protocol.md`.
  - Covers: R2, R3.
- [ ] T1.3 List every place where prompts currently define or imply
  permissions.
  - Covers: R3, R7.
- [ ] T1.4 Identify role separation drift: leader writes, reviewer edits,
  implementer approves or auditor implements.
  - Covers: R9.

## Phase 2 - Agent Contract System

- [ ] T2.0 Add `HL0_agent_authority` as the first hard lock for 0.10.0.
  - Covers: R2, R3, R3A.
- [ ] T2.1 Create `orquestador/agents/agent-registry.yaml` with
  `agent_definition_authority: harness_only`.
  - Covers: R2, R3, R4.
- [ ] T2.2 Create `orquestador/agents/capability-registry.yaml`.
  - Covers: R7, R8, R13.
- [ ] T2.3 Create `orquestador/agents/lifecycle-registry.yaml`.
  - Covers: R14, R15.
- [ ] T2.4 Create role contracts for leader, implementer, reviewer, auditor,
  reporter, spec-author and worker.
  - Covers: R5, R6, R9, R10.
- [ ] T2.5 Create security profiles for read-only, write-scoped,
  reviewer-readonly, auditor-blocking and release-manager.
  - Covers: R11, R12.
- [ ] T2.6 Create handoff contracts for leader-to-implementer,
  implementer-to-reviewer, reviewer-to-leader, auditor-to-leader and
  reporter-to-human.
  - Covers: R14, R15.
- [ ] T2.7 Define compatibility behavior for old prompts that mention roles.
  - Covers: R3, R3A, R23.
- [ ] T2.8 Declare `agents/*.md` as human documentation, not canonical runtime
  authority.
  - Covers: R3A, R23.

## Phase 2B - Agent Runtime Enablement

- [ ] T2B.1 Create `orquestador/agents/runtime-profiles/` for leader,
  implementer, reviewer, auditor and reporter.
  - Covers: R15A.
- [ ] T2B.2 Define runtime profile fields: mission, operating loop, required
  inputs, expected outputs, decision policy, validation routine, escalation
  triggers and stop conditions.
  - Covers: R15A.
- [ ] T2B.3 Create `orquestador/agents/context-packs/` with minimal
  role-specific context and denied-by-default refs.
  - Covers: R15B.
- [ ] T2B.4 Create `orquestador/agents/tool-packs/` constrained by
  capabilities, security profiles and AppSec policies.
  - Covers: R15C.
- [ ] T2B.5 Create `orquestador/agents/playbooks/` with workflow steps,
  checkpoints, output contracts, examples and anti-patterns per role.
  - Covers: R15D.
- [ ] T2B.6 Create `orquestador/agents/failure-modes/` for common role failure
  patterns and required response.
  - Covers: R15D, R15F.

## Phase 2C - Model adapter profiles

- [ ] T2C.1 Create `orquestador/agents/model-adapter-profiles.yaml`.
  - Covers: R15E.
- [ ] T2C.2 Define profiles for simple/acotado, standard and strong models.
  - Covers: R15E.
- [ ] T2C.3 Map model capability to autonomy level, context strategy,
  verification depth, max task span and escalation threshold.
  - Covers: R15E.
- [ ] T2C.4 Ensure model adapter profiles cannot grant authority absent from
  the role contract or capability registry.
  - Covers: R2, R7, R15E.

## Phase 3 - Security & AppSec

### Phase 3A - Threat model and schemas

- [ ] T3A.1 Create `orquestador/security/threat-model.yaml` covering
  malicious prompts, untrusted repos, unsafe YAML, command injection, path
  traversal, symlink escape, secret exposure, network/git abuse, unsafe
  backups and supply-chain risk.
  - Covers: R13A.
- [ ] T3A.2 Define schemas for all security registries and decide whether
  unknown keys fail closed or warn.
  - Covers: R12, R13B.
- [ ] T3A.3 Define security decision precedence:
  `explicit_deny > missing_contract_block > missing_capability_block >
  requires_preflight > allow_readonly`.
  - Covers: R8, R12, R13.

### Phase 3B - Permissions and capabilities

- [ ] T3B.1 Create `orquestador/security/permission-registry.yaml`.
  - Covers: R12.
- [ ] T3B.2 Map permissions to role contracts without duplicating role
  authority.
  - Covers: R7, R8, R12.
- [ ] T3B.3 Add fail-closed behavior for permissions absent from both role
  contract and registry.
  - Covers: R7, R8.

### Phase 3C - Command execution safety

- [ ] T3C.1 Create `orquestador/security/command-risk-registry.yaml`.
  - Covers: R13, R13C.
- [ ] T3C.2 Classify commands as `read_only`, `local_validation`, `write`,
  `destructive`, `network`, `git_remote`, `secrets` or `privileged`.
  - Covers: R13C.
- [ ] T3C.3 Define rules that prohibit string-built execution from untrusted
  YAML, prompt text or migration input.
  - Covers: R13C.
- [ ] T3C.4 Require capability, preflight, human `SI` and evidence for
  destructive, network, git remote, secrets and privileged command classes.
  - Covers: R13.

### Phase 3D - Write scope and path safety

- [ ] T3D.1 Create `orquestador/security/write-scope-registry.yaml`.
  - Covers: R8, R13B.
- [ ] T3D.2 Define path normalization rules for project root, harness root,
  relative paths and absolute paths.
  - Covers: R13B.
- [ ] T3D.3 Block path traversal, symlink/junction escape, writes outside
  approved roots and writes to `.git/`, home, shell profiles or unapproved
  temp paths.
  - Covers: R13B.
- [ ] T3D.4 Require active lock and approved write-set before any write action.
  - Covers: R8.

### Phase 3E - Network, secrets, escalation and supply chain

- [ ] T3E.1 Create `orquestador/security/network-policy.yaml` with default
  deny and allowlist fields for domain, endpoint, method/tool, purpose,
  expiry and evidence.
  - Covers: R13, R13E.
- [ ] T3E.2 Create `orquestador/security/secrets-policy.yaml` with default
  deny, sensitive-pattern detection, redaction, chat-output prohibition and
  explicit approval for secret-bearing paths.
  - Covers: R13D.
- [ ] T3E.3 Create `orquestador/security/escalation-policy.yaml`.
  - Covers: R13.
- [ ] T3E.4 Create `orquestador/security/supply-chain-policy.yaml` blocking
  dependency installs and remote code execution without explicit approval,
  provenance and checksum/lockfile strategy when available.
  - Covers: R13E.
- [ ] T3E.5 Create `orquestador/security/logging-policy.yaml` for secure
  evidence, redaction and forbidden output.
  - Covers: R13F.

### Phase 3F - Migration security

- [ ] T3F.1 Add backup permission, manifest/checksum and recovery requirements
  for migration apply.
  - Covers: R18, R13F.
- [ ] T3F.2 Define fail-closed behavior when backup creation, backup
  verification or redaction fails.
  - Covers: R18, R13F.
- [ ] T3F.3 Ensure migration never executes downloaded remote code.
  - Covers: R13E.

### Phase 3G - Negative AppSec fixtures

- [ ] T3G.1 Define negative fixture for path traversal outside project root.
  - Covers: R13B.
- [ ] T3G.2 Define negative fixture for symlink or junction escape.
  - Covers: R13B.
- [ ] T3G.3 Define negative fixture for command injection through YAML or
  prompt-controlled values.
  - Covers: R13C.
- [ ] T3G.4 Define negative fixture for secret leakage into logs, reports or
  chat output.
  - Covers: R13D, R13F.
- [ ] T3G.5 Define negative fixture for network without allowlist and human
  approval.
  - Covers: R13E.
- [ ] T3G.6 Define negative fixture for git remote write without explicit
  capability and approval.
  - Covers: R13.
- [ ] T3G.7 Define negative fixture for dependency install or downloaded script
  execution without provenance and approval.
  - Covers: R13E.
- [ ] T3G.8 Define negative fixture for backup failure during migration apply.
  - Covers: R18, R13F.

## Phase 4 - Migration service design files

- [ ] T4.1 Create `orquestador/migration/migration-registry.yaml` with route
  metadata.
  - Covers: R16, R23.
- [ ] T4.2 Create route file
  `orquestador/migration/versions/0.9.0-to-0.10.0.yaml`.
  - Covers: R16, R17, R18, R19.
- [ ] T4.3 Create route file
  `orquestador/migration/versions/0.8.10-to-0.10.0.yaml`.
  - Covers: R16, R17, R18, R19.
- [ ] T4.4 Create
  `orquestador/migration/contracts/post-migration-contract.yaml`.
  - Covers: R20, R21.
- [ ] T4.5 Create
  `orquestador/migration/reports/migration-report.template.yaml`.
  - Covers: R20, R21, R25.
- [ ] T4.6 Define never-overwrite rules for state, registry, cycles, locks,
  approvals, local/project memory and evidence.
  - Covers: R19.

## Phase 5 - Migration script

- [ ] T5.1 Add `scripts/migrate-harness.ps1` with `-CheckOnly`.
  - Covers: R16, R17.
- [ ] T5.2 Prove `-CheckOnly` performs no writes.
  - Covers: R17.
- [ ] T5.3 Add `scripts/migrate-harness.ps1` with `-Apply`.
  - Covers: R18, R19, R20.
- [ ] T5.4 Make backup mandatory before first write.
  - Covers: R18.
- [ ] T5.5 Preserve local state and merge only declared files.
  - Covers: R19.
- [ ] T5.6 Write migration report with route, backup, files changed,
  validators, risks and post-migration contract.
  - Covers: R20, R21, R25.
- [ ] T5.7 Fail closed if post-migration contract is only present but not
  active.
  - Covers: R21.

## Phase 6 - Validators

- [ ] T6.1 Add `scripts/validate-agent-contracts.ps1`.
  - Covers: R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R14, R15, R15A, R15B,
    R15C, R15D, R15E, R15F.
- [ ] T6.2 Add `scripts/validate-security-policy.ps1`.
  - Covers: R12, R13, R13A, R13B, R13C, R13D, R13E, R13F.
- [ ] T6.3 Add `scripts/validate-migration.ps1`.
  - Covers: R16, R17, R18, R19, R20, R21.
- [ ] T6.4 Add `scripts/audit-harness.ps1`.
  - Covers: R22, R25.
- [ ] T6.5 Integrate new validators into `scripts/validate-harness.ps1`.
  - Covers: R22.
- [ ] T6.6 Integrate minimum registry checks into `init.sh`.
  - Covers: R22, R23.

## Phase 6B - Agent quality evaluators

- [ ] T6B.1 Create `orquestador/agents/evaluation-rubrics/` for each
  instantiable role.
  - Covers: R15F.
- [ ] T6B.2 Add rubric checks for role-specific output quality, evidence,
  scope compliance and closure readiness.
  - Covers: R15F.
- [ ] T6B.3 Make failed rubrics block handoff or trigger escalation.
  - Covers: R15F.
- [ ] T6B.4 Add negative tests for missing runtime profile, missing context
  pack, missing tool pack, missing playbook, missing rubric and model adapter
  attempting to grant extra authority.
  - Covers: R15A, R15B, R15C, R15D, R15E, R15F.

## Phase 7 - Registry and prompt alignment

- [ ] T7.1 Add agent, security and migration entries to
  `orquestador/registry-index.yaml`.
  - Covers: R23.
- [ ] T7.2 Add gates for agent authority, security policy and migration
  applied.
  - Covers: R21, R25.
- [ ] T7.3 Update source-of-truth documentation so prompts cannot define
  agents.
  - Covers: R2, R3.
- [ ] T7.4 Rewrite role prompts so they reference contracts instead of
  declaring permissions.
  - Covers: R3, R23.
- [ ] T7.5 Add compatibility notes for projects staying on 0.9.0.
  - Covers: R24.

## Phase 8 - Required negative tests

- [ ] T8.1 Agent validator fails when a prompt mentions a role absent from
  `agent-registry.yaml`.
  - Covers: R3, R4.
- [ ] T8.2 Agent validator fails when a role contract path is missing.
  - Covers: R5, R6.
- [ ] T8.3 Agent validator fails when reviewer has write capability.
  - Covers: R9.
- [ ] T8.4 Agent validator fails when implementer can approve.
  - Covers: R9.
- [ ] T8.5 Agent validator fails when leader can implement.
  - Covers: R9.
- [ ] T8.6 Security validator fails when write occurs without capability and
  write scope.
  - Covers: R8.
- [ ] T8.7 Security validator fails when network, git remote, secrets or
  escalation lacks approval and evidence.
  - Covers: R13.
- [ ] T8.8 Security validator fails on path traversal, symlink escape,
  command injection, secret leak, unsafe network, git remote abuse and
  unapproved dependency execution.
  - Covers: R13A, R13B, R13C, R13D, R13E.
- [ ] T8.9 Migration validator fails when backup is missing.
  - Covers: R18.
- [ ] T8.10 Migration validator fails when post-migration contract exists but
  active contract was not updated.
  - Covers: R20, R21.
- [ ] T8.11 CheckOnly test fails if any file timestamp changes.
  - Covers: R17.

## Phase 9 - Migration simulations

- [ ] T9.1 Simulate 0.9.0 -> 0.10.0 on a temporary bound fixture.
  - Covers: R16, R19, R20, R21.
- [ ] T9.2 Simulate 0.8.10 -> 0.10.0 on a temporary bound fixture.
  - Covers: R16, R19, R20, R21.
- [ ] T9.3 Confirm state, registry, cycles, locks, approvals, local memory,
  project memory and evidence are preserved.
  - Covers: R19.
- [ ] T9.4 Confirm migration report references backup and validators.
  - Covers: R20, R21, R25.
- [ ] T9.5 Confirm rollback path or manual recovery instructions exist.
  - Covers: R18, R25.

## Phase 10 - Version and release gate

- [ ] T10.1 Only after all previous phases pass, decide whether to change
  `HARNESS_VERSION` to 0.10.0.
  - Covers: R24.
- [ ] T10.2 Update `PROJECT_BINDING.yaml` template version only during the
  release step.
  - Covers: R24.
- [ ] T10.3 Update changelog and migration prompt only after runtime files and
  validators pass.
  - Covers: R22, R25.
- [ ] T10.4 Run full audit including negative tests.
  - Covers: R22.
- [ ] T10.5 Prepare commit or release only with explicit approval.
  - Covers: R25.

## Approval needed to leave spec phase

A later approval must name:

- whether work starts on a branch or local slice;
- exact runtime files to add;
- exact scripts to write;
- baseline validators to run first;
- migration fixtures to use;
- whether versioning to 0.10.0 is in scope;
- whether commit, push or tag are allowed.
