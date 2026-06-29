# Indice del Sistema Operativo

Desde 0.9.0, el orquestador tambien gobierna memoria operativa por capas en `memory/`, entrypoints de rehidratacion en `entrypoints/` y adapters por IA en `adapters/`.

| Directorio / Archivo | Contenido | Responsabilidad |
|---|---|---|
| `../PROJECT_BINDING.yaml` | Binding de proyecto | Distingue fuente libre de harness vinculado |
| `harness-manifest.txt` | Manifest estructural | Lista canonica de directorios y archivos validados por `init.sh` |
| `memory/` | Memoria operativa | Capas local, diaria, ciclo, proyecto y completa |
| `entrypoints/` | Arranque y re-entry | Primer mensaje, reentry light/full, debug logs y compactacion |
| `adapters/` | Compatibilidad IA | Codex, Claude, Gemini, Qwen, DeepSeek, Cursor, Copilot y generico |
| `method/session-contract.md` | Contrato obligatorio | Bootstrap, hard locks, chat como interprete, leader visible |
| `method/harness-resolution.md` | Resolucion del harness | Bootstrap, copia, binding y anti-contaminacion |
| `method/evidence-reconstruction.md` | Reconstruccion historica | Hechos, inferencias, contradicciones y gaps antes de narrativa |
| `method/changelog-policy.md` | Versionado y changelog | Gate para changelog, release notes y docs historicas |
| `method/deploy-migration-policy.md` | Deploy/migracion | Evidencia de entorno, comandos, rollback y version |
| `method/reference-drift-policy.md` | Drift de referencias | Version, binding, README, changelog, prompts e init |
| `method/ci-pipeline-policy.md` | CI/pipeline | Iteraciones, logs y evidencia hasta pipeline funcional |
| `method/backlog-policy.md` | Roadmap | Clasificacion P0/P1/P2 |
| `method/audit-reporting-policy.md` | Auditor/reporter | Veredicto por evidencia y reporte fiel |
| `method/final-report-evidence-policy.md` | Cierre | Final report con cross-links a evidencia |
| `method/ai-preset-policy.md` | Presets IA | Codex, Claude, Gemini y re-entry |
| `method/` | Esencia operativa | SDD, roles, modos, protocolo multiagente y AI Engineering |
| `context/` | Arquitectura y Producto | El que y por que del sistema |
| `sdd/` | Especificaciones y Progreso | Contratos, state, registry, locks, gates, audit trail, agent closure, handoffs y evidencia |
| `policies/` | Permisos y Riesgos | Reglas de ownership, escalada y seguridad |

## Lectura Minima por Tarea

- Cualquier sesion: `../PROJECT_BINDING.yaml` + `method/session-contract.md`.
- Re-entry liviano: `memory/local/session-pin.md` + `memory/memory-registry.yaml` + `entrypoints/reentry-light.md`.
- Logs/debug: `entrypoints/debug-log-intake.md`.
- Configurar IA: `adapters/` + `method/adapter-contract.md` + `method/ai-preset-policy.md`.
- Validacion estructural: `harness-manifest.txt` + `../init.sh`.
- Duda de ruta o bootstrap: `method/harness-resolution.md`.
- Changelog, release notes o docs historicas: `method/evidence-reconstruction.md` + `method/changelog-policy.md`.
- Deploy/migracion: `method/deploy-migration-policy.md`.
- Versionado del harness: `method/reference-drift-policy.md`.
- CI/pipeline: `method/ci-pipeline-policy.md`.
- Roadmap: `method/backlog-policy.md`.
- Auditoria/reporte: `method/audit-reporting-policy.md`.
- Cierre: `method/final-report-evidence-policy.md`.
- Presets por IA: `method/ai-preset-policy.md`.
- Orquestacion: `method/multiagent-protocol.md` + `method/operating-modes.md`.
- Integracion LLM/tools: `method/ai-engineering.md`.
- Escritura o comandos: `policies/permissions.md` + `policies/tool-policy.yaml` + `policies/command-taxonomy.md` + `policies/write-set-policy.md`.
- Implementacion SDD: `method/sdd.md` + `sdd/specs/<feature>/` + `sdd/progress/registry.md`.

## Economia de Contexto

- `context-profiles.md` define que leer por rol.
- `method/global-rules.md` concentra reglas repetidas.
- `sdd/specs/bootstrap-harness.md` conserva el brief largo de bootstrap fuera del prompt diario.

## Registries canonicos

Las rutas operativas se gobiernan desde orquestador/registry-index.yaml. Los documentos narrativos explican el criterio; los registries son la fuente verificable para prompts, adapters, perfiles, gates, policies y templates.
