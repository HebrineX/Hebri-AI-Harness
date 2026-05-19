# Indice del Sistema Operativo

| Directorio / Archivo | Contenido | Responsabilidad |
|---|---|---|
| `method/` | Esencia operativa | SDD, roles, modos, protocolo multiagente y AI Engineering |
| `context/` | Arquitectura y Producto | El que y por que del sistema |
| `sdd/` | Especificaciones y Progreso | Contratos, registry, locks, gates, handoffs y evidencia |
| `policies/` | Permisos y Riesgos | Reglas de ownership, escalada y seguridad |

## Lectura Minima por Tarea

- Orquestacion: `method/multiagent-protocol.md` + `method/operating-modes.md`.
- Integracion LLM/tools: `method/ai-engineering.md`.
- Escritura o comandos: `policies/permissions.md` + `policies/risk-criteria.md`.
- Implementacion SDD: `method/sdd.md` + `sdd/specs/<feature>/` + `sdd/progress/registry.md`.

## Economia de Contexto

- `context-profiles.md` define que leer por rol.
- `method/global-rules.md` concentra reglas repetidas.
- `sdd/specs/bootstrap-harness.md` conserva el brief largo de bootstrap fuera del prompt diario.
