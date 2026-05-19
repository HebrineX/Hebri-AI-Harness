# Context Profiles

No cargues todo `.hebrinex` por defecto. Elegi el perfil minimo para la tarea.

## Perfil `leader` (~2k-3k tokens)

Leer:
- `AGENTS.md`
- `PROGRESS.md`
- `orquestador/method/operating-modes.md`
- `orquestador/method/multiagent-protocol.md`
- `orquestador/method/global-rules.md`
- `orquestador/sdd/progress/registry.md`
- `orquestador/sdd/progress/blocked.md`

Opcional:
- spec activa en `orquestador/sdd/specs/<feature>/`
- ultimo handoff en `orquestador/sdd/progress/cycles/`

No leer:
- `prompts/crear-harness.prompt.md`
- `orquestador/sdd/specs/bootstrap-harness.md`
- `orquestador/method/ai-engineering.md`, salvo integracion LLM/tools

## Perfil `spec_author` (~1.5k-3k tokens)

Leer:
- `orquestador/method/global-rules.md`
- `orquestador/method/sdd.md`
- `orquestador/context/product.md`
- `orquestador/context/architecture.md`
- `orquestador/sdd/specs/_template/`
- `prompts/spec-author.prompt.md`

Opcional:
- archivos de codigo pedidos por explorer/leader, solo lectura

## Perfil `implementer` (~2k-4k tokens)

Leer:
- `orquestador/method/global-rules.md`
- `orquestador/policies/permissions.md`
- `orquestador/policies/risk-criteria.md`
- `orquestador/sdd/specs/<feature>/requirements.md`
- `orquestador/sdd/specs/<feature>/design.md`
- `orquestador/sdd/specs/<feature>/tasks.md`
- `orquestador/sdd/progress/registry.md`
- lock activo en `orquestador/sdd/progress/locks/`
- `prompts/implementer.prompt.md`

No leer:
- biblioteca completa de gaps, salvo que registre un gap
- prompts de otros roles

## Perfil `reviewer` (~2k-4k tokens)

Leer:
- `orquestador/method/global-rules.md`
- `orquestador/sdd/specs/<feature>/`
- artefacto `impl_*.md`
- `gate-log.md` si existe
- `prompts/reviewer.prompt.md`

Opcional:
- diff o archivos tocados por implementer

## Perfil `ai_engineering` (~2k-5k tokens)

Leer solo cuando se conectan LLMs, tools o runtime:
- `orquestador/method/ai-engineering.md`
- `orquestador/policies/permissions.md`
- `orquestador/policies/risk-criteria.md`
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
| ai_engineering | 5k tokens |
| bootstrap | 8k tokens |
