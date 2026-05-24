# Futuras Mejoras P1/P2

Estas mejoras quedan listadas para una version posterior. No son obligatorias hasta que se promuevan a P0 o se implemente una spec aprobada.

## P1 Candidatas

- Migrar `registry.md` completamente a vista generada desde `registry.yaml` o `registry.jsonl`.
- Convertir locks en `L-XXX.lock.yaml` con `released_at`, `release_reason` y `evidence_ref`.
- Crear `audit-event.schema.yaml` para validar `audit.jsonl`.
- Crear `agent-registry.yaml` separado de ciclos para agentes activos, slots, ownership, handoffs y closures.
- Agregar `archive-policy.md` para specs/ciclos activos, cerrados y legacy.
- Agregar `risk-before-close.md` para riesgo residual, rollback, deuda nueva e impacto.
- Unificar frontmatter de todos los prompts y agents con `id`, `version`, `schema_version`, `role`, `allowed_actions`, `output_schema` y `context_profile`.
- Crear playbook completo de desvio detectado.
- Agregar validadores locales `validate-harness`, `validate-session`, `validate-registry` y `validate-gates`.
- Crear ejemplos piloto auditor/reporter/detractor.

## P2 Candidatas

- Politica de worktrees para paralelismo real.
- Presets por IA: Codex, Claude Code, Gemini y generico.
- Compatibilidad externa parcial con formatos SDD/agentes sin romper contrato Hebri.
- Micro-specs opcionales junto a codigo.
- Crear `infoHebri.md` solo cuando el harness demuestre funcionamiento completo y respeto operativo consistente en un proyecto real.
