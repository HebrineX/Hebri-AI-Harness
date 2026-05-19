# Roles Cerrados y Handoff

La separación de roles previene auto-aprobación y loops infinitos.

| Rol | Entrada Permitida | Salida Obligatoria | Escalada (Cuándo parar) |
|---|---|---|---|
| **leader** | Estado de `PROGRESS.md`, outputs de agentes | Decisión de enrutamiento | Bloqueo o falta de recursos |
| **spec_author** | Issue, contexto | `requirements.md`, `design.md`, `tasks.md` | Alcance requiere decisión humana |
| **implementer** | Spec aprobada, ownership, tests | Diff acotado, evidencia (`comando exitoso`) | Necesita salir del ownership |
| **reviewer** | Diff, Spec, Tests | Aprobación o Lista de hallazgos para arreglar | Resultado contradice el contrato de base |

## Reglas de Handoff (Anti-Teléfono Descompuesto)
- Prohibido resumir salidas pasadas: los subagentes ESCRIBEN RESULTADOS EN ARCHIVOS y devuelven SOLO UNA REFERENCIA (ej: "Revisión completada en progress/review_feature.md").
- El chat se usa para orquestar. Los archivos conservan la verdad y el estado.
