# Context Profiles

Version: 0.10.9

Objetivo: cargar el minimo contexto posible. El default debe ahorrar 70-80% frente a leer `AGENTS.md + session-contract + method/* + prompts/**`.

Antes de leer un perfil, revisar `orquestador/context-profile-registry.yaml`, `orquestador/context-budget.yaml` y `orquestador/prompt-registry.yaml` si el perfil carga prompts.

## `memory_bootstrap` <= 1500 tokens

Leer:
- `PROJECT_BINDING.yaml`
- `orquestador/memory/local/session-pin.md`
- `orquestador/memory/memory-registry.yaml`
- `orquestador/memory/memory-routing.yaml`
- entrypoint aplicable

Uso: inicio, re-entry, debug, cambio de tema.

## `first_message` <= 1800 tokens

Leer `memory_bootstrap` + memoria local minima. No leer contrato extendido.

## `debug_log_intake` <= 2000 tokens + logs del usuario

Leer:
- `memory_bootstrap`
- `orquestador/entrypoints/debug-log-intake.md`

No leer `leader_full` por recibir logs. Primero clasificar hechos, inferencias y comandos candidatos.

## `leader_light` <= 2600 tokens

Leer:
- `memory_bootstrap`
- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- `orquestador/sdd/progress/blocked.md` solo si `state.yaml` declara bloqueo o el operador reporta bloqueo
- `orquestador/method/session-contract.md`

Uso: coordinacion normal, plan corto, preflight, estado al operador.

## `leader_full` <= 8000 tokens, requiere motivo

Leer solo si `leader_light` no alcanza:
- `leader_light`
- `orquestador/method/session-contract-extended.md`
- politica especifica del caso
- evidencia del ciclo activo

Requiere explicar motivo. Si supera presupuesto, pedir brief mas acotado.

## `spec_author` <= 3000 tokens

Leer:
- `orquestador/method/sdd.md`
- `orquestador/context/product.md`
- `orquestador/context/architecture.md`
- templates SDD necesarios
- `prompts/roles/spec-author.prompt.md`

## `implementer` <= 4000 tokens

Leer:
- spec activa: requirements/design/tasks
- `orquestador/policies/permissions.md`
- `orquestador/policies/risk-criteria.md`
- `orquestador/policies/tool-policy.yaml`
- lock activo si existe
- `prompts/roles/implementer.prompt.md`

## `reviewer` <= 4000 tokens

Leer spec activa, artefacto implementado, gate log/evidencia del alcance y `prompts/roles/reviewer.prompt.md`.

## `auditor` <= 4000 tokens

Leer state, registry, gates/evidencia del ciclo auditado, `agents/auditor.md` y detractor pass si aplica.

## `reporter` <= 2000 tokens

Leer output de auditor/reviewer/leader, audiencia objetivo, `agents/reporter.md` y solo evidencia referenciada.

## Perfiles Especiales

| Perfil | Presupuesto | Carga |
|---|---:|---|
| `release` | <= 6000 | changelog, evidence reconstruction, registry, git log y matriz historica |
| `deploy_migration` | <= 6000 | deploy policy, scripts/docs de deploy y evidencia |
| `version_drift` | <= 4000 | HARNESS_VERSION, binding, README, CHANGELOG, init, prompts de migracion |
| `ci_pipeline` | <= 6000 | workflows, logs, commits relevantes y pipeline policy |
| `backlog` | <= 4000 | PROGRESS, future-p1, registry y backlog policy |
| `preset_ai` | <= 4000 | adapter contract, adapter especifico y preset puntual |
| `ai_engineering` | <= 5000 | solo si hay LLM/tools/runtime |
| `bootstrap` | <= 8000 | manifest, bootstrap spec y migracion |
| `audit_global` | <= 12000 | requiere preflight y `SI` |

## Denegado por Defecto

- `infoHebri.md`
- `orquestador/memory/complete/*`
- leer todo `orquestador/method/`
- leer todo `prompts/` o todas sus subcarpetas
- leer todo `.hebrinex/`

Si un agente necesita superar presupuesto, debe detenerse, explicar read-set y pedir autorizacion.

## Runtime 0.10.9

- `runtime_status`: `PROJECT_BINDING.yaml`, `session-pin.md`, `context-budget.yaml` y `active-session` si existe. Maximo: 900 tokens.
- `runtime_reentry`: runtime status + `state.yaml`/`registry.yaml` solo si entra en budget. Maximo: 1600 tokens.
- `/harness audit` prepara preflight; no carga auditoria global automaticamente.

## Claude 0.9.0

- `claude_reentry`: binding + session pin + runtime Claude brief. No carga memoria completa.
