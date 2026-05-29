# Indice del Sistema Operativo

| Directorio / Archivo | Contenido | Responsabilidad |
|---|---|---|
| `../PROJECT_BINDING.yaml` | Binding de proyecto | Distingue fuente libre de harness vinculado |
| `method/session-contract.md` | Contrato obligatorio | Bootstrap, hard locks, chat como interprete, leader visible |
| `method/harness-resolution.md` | Resolucion del harness | Bootstrap, copia, binding y anti-contaminacion |
| `method/` | Esencia operativa | SDD, roles, modos, protocolo multiagente y AI Engineering |
| `context/` | Arquitectura y Producto | El que y por que del sistema |
| `sdd/` | Especificaciones y Progreso | Contratos, state, registry, locks, gates, audit trail, agent closure, handoffs y evidencia |
| `policies/` | Permisos y Riesgos | Reglas de ownership, escalada y seguridad |

## Lectura Minima por Tarea

- Cualquier sesion: `../PROJECT_BINDING.yaml` + `method/session-contract.md`.
- Duda de ruta o bootstrap: `method/harness-resolution.md`.
- Orquestacion: `method/multiagent-protocol.md` + `method/operating-modes.md`.
- Integracion LLM/tools: `method/ai-engineering.md`.
- Escritura o comandos: `policies/permissions.md` + `policies/tool-policy.yaml` + `policies/command-taxonomy.md` + `policies/write-set-policy.md`.
- Implementacion SDD: `method/sdd.md` + `sdd/specs/<feature>/` + `sdd/progress/registry.md`.

## Economia de Contexto

- `context-profiles.md` define que leer por rol.
- `method/global-rules.md` concentra reglas repetidas.
- `sdd/specs/bootstrap-harness.md` conserva el brief largo de bootstrap fuera del prompt diario.
