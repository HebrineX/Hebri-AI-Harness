# Hebri-AI-Harness

Referencia operativa actual: **0.9.0**.

Sistema operativo para agentes IA basado en [Hebri-AI-Structure](https://github.com/HebrineX/Hebri-AI-Structure). Objetivo: contrato, trazabilidad y aprobaciones con 70-80% menos contexto frente a leer todo `.hebrinex`.

## Uso Diario

1. Validar `PROJECT_BINDING.yaml`.
2. Cargar kernel minimo: `session-pin`, `memory-registry`, `memory-routing`, `context-budget` y entrypoint.
3. Declarar contrato de sesion.
4. Elegir perfil minimo desde `orquestador/context-profiles.md`.
5. Pedir `SI` antes de efectos.
6. Ejecutar `auditor(profile: detractor_senior)` antes de implementar o escribir.`n7. Cerrar con evidencia y `memory-closure-checklist.md` si hubo trabajo operativo.

## Presupuestos

| Ruta | Presupuesto |
|---|---:|
| `memory_bootstrap` | <= 1700 tokens |
| `first_message` | <= 1800 tokens |
| `reentry_light` | <= 1800 tokens |
| `debug_log_intake` | <= 2000 tokens + logs |
| `leader_light` | <= 2600 tokens |
| `leader_full` | <= 8000 tokens y requiere motivo |
| `audit_global` | <= 12000 tokens y requiere `SI` |

Denegado por defecto: `infoHebri.md`, memoria `complete/`, `CHANGELOG.md`, `README.md`, manifest, `init.sh`, prompts completos y todos los metodos.

## Bootstrap Seguro

Si un proyecto no tiene `.hebrinex`, no se opera con un harness externo. Se copia una fuente libre `source_template` a `<project_root>/.hebrinex/`, excluyendo materialmente `infoHebri.md`, `.git/` y temporales, y luego se vincula como `bound`.

## Novedades Actuales

- `init.sh` bloquea drift de version operativo fuera de `CHANGELOG.md`.
- `state.yaml` queda estructuralmente valido.
- Adapters y presets usan entrada minima: binding, session pin, registry, routing, budget y entrypoint.
- `memory-closure-checklist.md` obliga a cerrar local/daily/cycle/project antes de `done`.
- Bootstrap/migracion excluyen materialmente `infoHebri.md`.
## Validacion Local

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-harness.ps1 -RunNegativeTests
```

Esta validacion revisa manifest, schemas, presupuestos, exclusion de `infoHebri.md`, migracion bound simulada y presets livianos por defecto. No reemplaza el contrato del harness; lo protege contra drift estructural.

## Detractor Senior

Antes de implementar, el leader debe pasar por auditor(profile: detractor_senior) o registrar bypass aprobado. El objetivo es llegar al mismo resultado con menos codigo, menos dependencias y menos abstracciones, sin sacrificar seguridad, datos, accesibilidad, contrato ni evidencia.

## Adapter portability

El contrato portable vive en orquestador/portability/core-skills.yaml y la cobertura por IA en orquestador/portability/adapter-matrix.yaml. Los adapters .yaml son declarativos y se verifican con scripts/check-adapter-drift.ps1.
