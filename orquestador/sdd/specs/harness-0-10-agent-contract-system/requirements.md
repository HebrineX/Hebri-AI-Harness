# Requirements - Harness 0.10.0 Agent Contract System

## Estado

Esta spec es material de diseno para Hebri-AI-Harness 0.10.0.

El harness estable sigue siendo 0.9.0. Ningun archivo de esta spec cambia
`HARNESS_VERSION`, `PROJECT_BINDING.yaml`, manifest operativo, scripts ni
runtime. Cualquier spike local previo de 0.10.0 se considera referencia o
evidencia, no fuente de verdad.

## Problema

El harness gobierna agentes, pero no debe comportarse como un agente. Un
agente no debe existir porque una IA lo nombra en chat o porque un prompt
mezcla responsabilidades. Un agente debe existir solamente cuando el harness
lo declara en registros y contratos verificables.

La migracion a 0.10.0 debe resolver tres puntos:

- separar autoridad de harness y ejecucion de agentes;
- hacer verificables roles, permisos, capabilities, AppSec y handoffs;
- migrar desde versiones anteriores sin perder estado local ni dejar la
  migracion solo declarada.

## Objetivos

- Definir un Agent Contract System gobernado por el harness.
- Declarar autoridad `harness_only` para agentes, roles, permisos,
  capabilities, security profiles, lifecycle, handoffs y escalaciones.
- Definir Agent Runtime Enablement para que cada agente tenga mision,
  contexto, herramientas, loop operativo, evaluacion, escalacion y cierre
  acordes a su rol.
- Disenar seguridad informatica verificable: threat model, validacion de
  entradas, seguridad de comandos, secretos, red, supply chain, backups,
  logging seguro y casos negativos.
- Disenar un servicio de migracion 0.9.0 -> 0.10.0 y 0.8.10 -> 0.10.0.
- Definir criterios de exito para probar que el contrato post-migracion queda
  aplicado.

## No objetivos

- No crear scripts operativos en esta etapa.
- No crear registries runtime fuera de esta carpeta de spec.
- No versionar el harness como 0.10.0.
- No modificar `HARNESS_VERSION`.
- No modificar `PROJECT_BINDING.yaml`.
- No modificar `orquestador/harness-manifest.txt`, salvo como tarea futura.
- No migrar proyectos consumidores reales.
- No convertir prompts en fuente de autoridad para agentes.
- No prometer que el harness convierte un modelo limitado en un modelo de
  mayor capacidad cognitiva; el harness reduce ambiguedad, estructura trabajo,
  provee contexto/herramientas y valida outputs.
- No asumir que la arquitectura final ya esta cerrada.

## Autoridad

La autoridad propuesta para 0.10.0 es:

```yaml
agent_definition_authority: harness_only
ai_may_define_agents: false
ai_may_modify_agent_contracts: false
ai_may_escalate_capabilities: false
prompt_may_define_roles: false
```

La IA puede proponer contratos candidatos como texto de trabajo, pero esos
contratos no existen hasta que el harness los registre, valide y gobierne.

## Hard Lock 0

`HL0_agent_authority` es la regla madre de 0.10.0:

```text
Ninguna IA define agentes, roles, permisos ni escalaciones.
Solo el harness puede definir contratos de agente.
```

Formato operativo esperado cuando una IA solicite un rol:

```text
Rol solicitado:
Contrato harness:
Estado: instanciable | bloqueado
Motivo:
```

Si el contrato no existe, la unica salida valida es:

```text
Bloqueado: el harness no define ese agente.
```

## Agent Runtime Enablement

0.10.0 debe tratar a un agente como algo mas que permisos. Un agente efectivo
debe tener:

```text
contrato + contexto + herramientas + loop operativo + validacion + cierre
```

El harness debe poder tomar una IA simple o acotada y envolverla con estructura
operativa suficiente para acercarla al mejor comportamiento posible dentro de
su rol. Esto no cambia la capacidad intrinseca del modelo, pero reduce
ambiguedad, limita errores, provee contexto, habilita herramientas seguras,
obliga self-review y usa evaluadores externos.

## Requirements EARS

### R1 - Harness vs agent boundary

WHEN the harness starts a session, THE SYSTEM SHALL distinguish harness
authority from agent execution and SHALL NOT allow the visible chat, leader,
worker, reviewer or auditor to redefine that boundary.

### R2 - Harness-only agent definition

WHEN an agent, role, capability, security profile, handoff, lifecycle or
escalation is requested, THE SYSTEM SHALL resolve it from harness-owned
registries and contracts.

### R3 - No AI-defined agents

IF an AI response invents, renames, redefines or elevates an agent outside the
harness registries, THEN THE SYSTEM SHALL reject that agent and record a
blocking reason.

### R3A - Prompt cannot define agents

IF prompts, docs or runtime instructions contain operational language that
defines new agents, changes role permissions, mixes roles or grants escalation
outside harness registries, THEN THE SYSTEM SHALL fail validation or require an
explicit compatibility exception.

### R4 - Agent registry source of truth

WHEN a role is instantiated, THE SYSTEM SHALL require the role id to exist in
`orquestador/agents/agent-registry.yaml`.

### R5 - Role contract existence

WHEN a role id exists in `agent-registry.yaml`, THE SYSTEM SHALL require the
referenced role contract YAML to exist and pass schema validation before the
agent can be instantiated.

### R6 - Missing contract blocks execution

IF a role is missing from `agent-registry.yaml` OR its YAML contract is missing,
THEN THE SYSTEM SHALL treat the agent as non-existent and block execution.

### R7 - Capability enforcement

WHEN an agent requests an action, THE SYSTEM SHALL verify the requested
capability is declared, allowed for that role and compatible with the role
security profile.

### R8 - Write requires capability

IF an agent requests a write action without an explicit write capability,
approved write-scope and active lock, THEN THE SYSTEM SHALL block the action.

### R9 - Role separation

WHILE a cycle is active, THE SYSTEM SHALL prevent a reviewer from editing, an
implementer from approving, and a leader from implementing.

### R10 - Chat interpreter boundary

WHEN the visible chat is acting as interpreter, THE SYSTEM SHALL NOT let it
claim leader authority unless a harness contract assigns that slot explicitly.

### R11 - Security profile required

WHEN an agent is instantiated, THE SYSTEM SHALL attach exactly one security
profile from `orquestador/agents/security-profiles/` or block the
instantiation.

### R12 - Security registries

WHEN security decisions are evaluated, THE SYSTEM SHALL use structured
registries for permissions, command risk, write scope, network, secrets and
escalation.

### R13 - Network, git, secrets and elevated actions

IF an action uses network, git remote, secrets, destructive filesystem changes
or elevated privileges, THEN THE SYSTEM SHALL require an explicit capability,
risk class, preflight, human `SI` and evidence path.

### R13A - Threat model

WHEN 0.10.0 AppSec is implemented, THE SYSTEM SHALL define a threat model that
covers malicious prompts, untrusted repositories, unsafe YAML, command
injection, path traversal, symlink escape, secret exposure, network abuse, git
remote abuse, unsafe backups and supply-chain risk.

### R13B - Input and path validation

WHEN the harness accepts paths, YAML, command arguments, migration roots or
write scopes, THE SYSTEM SHALL normalize and validate them, SHALL reject path
traversal, SHALL block writes outside approved roots and SHALL not follow
symlinks outside the project root.

### R13C - Command execution safety

WHEN a script executes commands, THE SYSTEM SHALL classify command risk, SHALL
avoid string-built shell execution where structured argument APIs are
available, and SHALL block destructive, network, git remote or privileged
commands without explicit approval and evidence.

### R13D - Secret handling

WHEN files, logs, reports or command output may contain secrets, THE SYSTEM
SHALL default to deny access, redact sensitive values, block secret echoing to
chat/report output and require explicit approval for any secret-bearing path.

### R13E - Network and supply-chain safety

WHEN network or dependency installation is requested, THE SYSTEM SHALL default
to deny, require allowlisted endpoint or package intent, record provenance and
SHALL NOT execute downloaded remote code as part of migration.

### R13F - Secure logging and backups

WHEN the harness writes logs, evidence, migration reports or backups, THE
SYSTEM SHALL preserve traceability without secrets, verify backup creation and
record recovery instructions or rollback constraints.

### R14 - Handoff contract

WHEN an agent hands off work, THE SYSTEM SHALL require structured fields for
role, scope, files read, files changed, commands run, evidence, blockers,
risks and next suggested role.

### R15 - Closure contract

WHEN a cycle is declared complete, THE SYSTEM SHALL require all agents to have
closure, resolved locks, recorded handoffs, evidence and validator status.

### R15A - Runtime profile required

WHEN a role is instantiated, THE SYSTEM SHALL attach a runtime profile that
defines mission, operating loop, required inputs, expected outputs,
decision policy, validation routine, escalation triggers and stop conditions.

### R15B - Context pack required

WHEN an agent starts work, THE SYSTEM SHALL provide a minimal role-specific
context pack and SHALL avoid loading unrelated harness memory or project
context unless the runtime profile explicitly requires it.

### R15C - Tool pack required

WHEN an agent requests tools, THE SYSTEM SHALL resolve allowed tools from a
role-specific tool pack that is constrained by capabilities, security profile
and AppSec policy.

### R15D - Role playbook

WHEN an agent executes a task, THE SYSTEM SHALL provide a role playbook with
workflow steps, expected reasoning checkpoints, output contract,
anti-patterns and examples.

### R15E - Model adapter profile

WHEN a provider/model has limited capabilities, THE SYSTEM SHALL apply a model
adapter profile that adjusts context size, autonomy level, tool expectations,
verification depth and escalation thresholds.

### R15F - Agent quality evaluation

WHEN an agent produces output, THE SYSTEM SHALL evaluate it against a
role-specific rubric before closure or handoff, and SHALL block or escalate if
minimum quality gates fail.

### R16 - Migration route detection

WHEN migration is requested, THE SYSTEM SHALL detect current version, target
version, binding mode, project root, harness path and supported migration
route before planning writes.

### R17 - CheckOnly mode

WHEN migration runs in `CheckOnly` mode, THE SYSTEM SHALL write no files and
SHALL produce a plan with route, backup requirement, preservation list, merge
list, validation list and expected post-migration contract.

### R18 - Apply mode backup

WHEN migration runs in `Apply` mode, THE SYSTEM SHALL create a backup before
any write and SHALL fail closed if the backup cannot be created or verified.

### R19 - Local state preservation

WHEN migrating a bound project, THE SYSTEM SHALL preserve `state.yaml`,
`registry.yaml`, cycles, locks, approvals, local memory, project memory and
evidence unless a merge rule explicitly says otherwise.

### R20 - Post-migration contract

WHEN migration apply finishes, THE SYSTEM SHALL write and activate a
post-migration contract that records target version, binding, project root,
agent authority, security policy, validators and migration status.

### R21 - Applied, not only declared

IF a post-migration contract exists but validators did not pass OR active
contract was not updated OR required registries are absent, THEN THE SYSTEM
SHALL report migration status as not applied.

### R22 - Validator integration

WHEN 0.10.0 runtime work is later approved, THE SYSTEM SHALL add validators for
agent contracts, AppSec/security policy, migration service and full harness
audit, then integrate them with `validate-harness.ps1` and `init.sh`.

### R23 - Registry integration

WHEN new agent, security or migration registries are added, THE SYSTEM SHALL
reference them from `orquestador/registry-index.yaml` or an equivalent
canonical registry before they can be treated as active.

### R24 - 0.9.0 compatibility

WHILE 0.10.0 remains in design, THE SYSTEM SHALL keep 0.9.0 operational
behavior intact and SHALL NOT require consumer projects to adopt 0.10.0 files.

### R25 - Auditability

WHEN a migration, block, override, escalation or closure decision is made, THE
SYSTEM SHALL store it as evidence, report or gate log rather than relying on
chat memory.

## Compatibility with 0.9.0

The 0.10.0 design must preserve these 0.9.0 authority paths:

- `PROJECT_BINDING.yaml`
- `HARNESS_VERSION`
- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- `orquestador/sdd/progress/cycles/`
- `orquestador/sdd/progress/locks/`
- `orquestador/sdd/progress/approvals/`
- `orquestador/memory/local/`
- `orquestador/memory/project/`
- `orquestador/context-budget.yaml`
- `orquestador/method/session-contract.md`

0.10.0 should be additive first. Any breaking change must be listed as a
future task with migration and rollback behavior.

## Acceptance criteria for this spec

- Requirements use testable language.
- Design separates harness authority from agent execution.
- Design includes `agent_definition_authority: harness_only`.
- Design includes `HL0_agent_authority`.
- Design includes Agent Runtime Enablement.
- Design treats `agents/*.md` as human documentation, not canonical runtime
  authority.
- Design includes AppSec controls for command injection, path traversal,
  symlink escape, secrets, network, git, supply chain, backups and logs.
- Design includes agent, security and migration structures.
- Design includes `0.9.0-to-0.10.0` and `0.8.10-to-0.10.0`.
- Tasks are implementable later by phase.
- No runtime 0.10.0 files are created outside this spec folder.
- 0.10.0 is not declared ready.
