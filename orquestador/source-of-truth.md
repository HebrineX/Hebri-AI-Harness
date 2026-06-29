# Fuentes canonicas y artefactos derivados

El harness se gobierna desde contratos chicos y verificables. Los documentos largos explican el criterio, pero las rutas operativas deben vivir en registries.

## Canonicos

| Dominio | Fuente canonica |
|---|---|
| Prompts | `orquestador/prompt-registry.yaml` |
| Adapters IA | `orquestador/adapter-registry.yaml` |
| Perfiles de contexto | `orquestador/context-profile-registry.yaml` + `orquestador/context-budget.yaml` |
| Gates | `orquestador/gate-registry.yaml` |
| Policies | `orquestador/policy-registry.yaml` |
| Templates | `orquestador/template-registry.yaml` |
| Estado de proyecto | `orquestador/sdd/progress/state.yaml` y `registry.yaml` |
| Runtime | `orquestador/runtime/*`, siempre no autoritativo |

## Derivados

- `orquestador/harness-manifest.txt` lista material distribuible y debe incluir todo lo canonico.
- `README.md`, `orquestador/README.md` y docs narrativos explican, no reemplazan registries.
- Prompts finales pueden generarse desde `orquestador/instruction-builder/`; no deben duplicar policies completas.

## Regla

Si una ruta operativa se repite en mas de un lugar, el proximo cambio debe moverla primero al registry correspondiente y despues adaptar el validador.
