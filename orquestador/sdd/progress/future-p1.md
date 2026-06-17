# Futuras Mejoras P1/P2

Estas mejoras quedan listadas para una version posterior. No son obligatorias hasta que se promuevan a P0 o se implemente una spec aprobada.

## Roadmap Incremental 0.7.x

La linea 0.7.x se usa para endurecer huecos operativos sin cambiar la estructura mayor del harness. Un salto a 0.8.x queda reservado para cambios de arquitectura, no para controles puntuales.

| Version | Estado | Foco | Criterio de promocion |
|---|---|---|---|
| 0.7.1 | Implementado P0 | Reconstruccion historica para changelog/release docs | Ningun changelog se edita sin matriz basada en `git log`, `PROGRESS.md`, registry y ciclos disponibles |
| 0.7.2 | Implementado P0 | Gate de deploy/migracion historica | Deploy docs y migraciones deben mapear scripts, entornos, comandos y evidencia de ejecucion |
| 0.7.3 | Implementado P0 | Gate de drift README/version/referencias | README, version files, prompts y docs raiz deben validar referencias cruzadas antes de cierre |
| 0.7.4 | Implementado P0 | Gate de evolucion CI/pipeline | Iteraciones de CI no se colapsan si hay evidencia de pasos distintos hasta llegar al pipeline funcional |
| 0.7.5 | Implementado P0 | Gate de backlog/roadmap | P0/P1/P2 deben quedar separados por impacto, bloqueo y dependencia, no por preferencia del agente |
| 0.7.6 | Implementado P0 | Gate de auditoria/reporting | Auditor y reporter deben separar veredicto, evidencia, inferencia y tono humano sin alterar el resultado |
| 0.7.7 | Implementado P0 | Cross-link final-report/evidence | Todo final report debe linkear gate log, verification matrix, agent closure y gaps abiertos |
| 0.7.8 | Implementado P0 | Presets anti-desvio por IA | Codex, Claude y Gemini deben tener presets equivalentes y chequeables contra el contrato |
| 0.7.9 | Implementado P0 | Optimizacion interna | Manifest central, init mas simple, bootstrap condensado y menor drift |
| 0.8.8 | Implementado P0 | Memoria estratificada multi-IA | Memory registry, routing, entrypoints y adapters para evitar reentry manual constante |
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
- Compatibilidad externa parcial con formatos SDD/agentes sin romper contrato Hebri.
- Micro-specs opcionales junto a codigo.
- Crear `infoHebri.md` solo cuando el harness demuestre funcionamiento completo y respeto operativo consistente en un proyecto real.
