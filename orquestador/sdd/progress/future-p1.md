# Futuras Mejoras P1

Estas mejoras quedan listadas para una version posterior. No son obligatorias hasta que se promuevan a P0 o se implemente una spec aprobada.

## P1 Candidatas

- Migrar `registry.md` completamente a `registry.yaml` o `registry.jsonl`, dejando Markdown solo como vista generada.
- Convertir locks en `L-XXX.lock.yaml` con `released_at`, `release_reason` y `evidence_ref`.
- Agregar `decision-log.jsonl` por ciclo o slice.
- Unificar frontmatter de todos los prompts y agents con `id`, `version`, `schema_version`, `role`, `allowed_actions`, `output_schema` y `context_profile`.
- Crear playbook completo de desvio detectado.
- Definir `worker-lite` para tareas sin SDD completo, bajo riesgo y ownership claro.
- Agregar validadores locales `validate-harness`, `validate-session`, `validate-registry` y `validate-gates`.
- Separar `explorar.prompt.md` y `diagnosticar.prompt.md`.
- Crear `infoHebri.md` solo cuando el harness demuestre funcionamiento completo y respeto operativo consistente en un proyecto real.
