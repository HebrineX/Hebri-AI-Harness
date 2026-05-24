# Context Profiles

No cargues todo `.hebrinex` por defecto. Elegi el perfil minimo para la tarea.

## Perfil `leader` (~2k-3k tokens)

Leer:
- `AGENTS.md`
- `PROGRESS.md`
- `orquestador/method/session-contract.md`
- `orquestador/method/operating-modes.md`
- `orquestador/method/multiagent-protocol.md`
- `orquestador/method/agent-role-taxonomy.md`
- `orquestador/method/global-rules.md`
- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- `orquestador/sdd/progress/registry.md`
- `orquestador/sdd/progress/blocked.md`

## Perfil `spec_author` (~1.5k-3k tokens)

Leer:
- `orquestador/method/global-rules.md`
- `orquestador/method/sdd.md`
- `orquestador/context/product.md`
- `orquestador/context/architecture.md`
- `orquestador/sdd/specs/_template/`
- `prompts/spec-author.prompt.md`

## Perfil `implementer` (~2k-4k tokens)

Leer:
- `orquestador/method/global-rules.md`
- `orquestador/policies/permissions.md`
- `orquestador/policies/risk-criteria.md`
- `orquestador/policies/tool-policy.yaml`
- `orquestador/policies/write-set-policy.md`
- `orquestador/sdd/specs/<feature>/requirements.md`
- `orquestador/sdd/specs/<feature>/design.md`
- `orquestador/sdd/specs/<feature>/tasks.md`
- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- lock activo en `orquestador/sdd/progress/locks/`
- `prompts/implementer.prompt.md`

## Perfil `reviewer` (~2k-4k tokens)

Leer:
- `orquestador/method/global-rules.md`
- `orquestador/sdd/specs/<feature>/`
- artefacto `impl_*.md`
- `gate-log.yaml` si existe
- `verification-matrix.yaml` si existe
- `final-report.md` si existe
- `prompts/reviewer.prompt.md`

## Perfil `auditor` (~2k-4k tokens)

Leer:
- `orquestador/method/global-rules.md`
- `orquestador/method/agent-role-taxonomy.md`
- `orquestador/method/multiagent-protocol.md`
- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- gate logs, audit trails, final reports y agent closures del ciclo auditado
- `agents/auditor.md`

## Perfil `reporter` (~1k-2k tokens)

Leer:
- output de auditor/reviewer/leader
- audiencia objetivo
- `agents/reporter.md`
- evidencia referenciada, no todo el repo

## Perfil `ai_engineering` (~2k-5k tokens)

Leer solo cuando se conectan LLMs, tools o runtime:
- `orquestador/method/ai-engineering.md`
- `orquestador/policies/permissions.md`
- `orquestador/policies/risk-criteria.md`
- `orquestador/policies/tool-policy.yaml`
- `orquestador/policies/write-set-policy.md`
- prompt o workflow especifico

## Perfil `bootstrap` (~4k-8k tokens)

Leer solo para crear o regenerar un harness:
- `prompts/crear-harness.prompt.md`
- `orquestador/sdd/specs/bootstrap-harness.md`
- `orquestador/method/global-rules.md`
- `orquestador/method/ai-engineering.md` si se agregan runtime/tools

## Presupuesto por defecto

| Perfil | Presupuesto objetivo |
|---|---:|
| leader | 3k tokens |
| spec_author | 3k tokens |
| implementer | 4k tokens |
| reviewer | 4k tokens |
| auditor | 4k tokens |
| reporter | 2k tokens |
| ai_engineering | 5k tokens |
| bootstrap | 8k tokens |
