# Prompts

Repositorio de prompts versionados del harness. La raiz queda reservada para este indice; los prompts ejecutables viven en subcarpetas por responsabilidad.

| Carpeta | Responsabilidad |
|---|---|
| `roles/` | Roles operativos: lider, implementer, reviewer, spec-author y worker. |
| `session/` | Inicio, brief, re-entry y recuperacion de contexto. |
| `adapters/` | Presets por IA; la capacidad canonica vive en `orquestador/adapters/`. |
| `migration/` | Migraciones, deploy y reconstruccion de CI/pipeline. |
| `audit/` | Auditoria, detractor y drift de version/referencias. |
| `runtime/` | Comandos `/harness` y runtime liviano no autoritativo. |
| `bootstrap/` | Creacion, arranque y primer mensaje de harness. |
| `workflows/` | Flujos repetibles del ciclo operativo. |

El registro canonico es `orquestador/prompt-registry.yaml`.