# Hebri-AI-Harness

Referencia operativa actual: **0.11.0**.

Sistema operativo para agentes IA basado en [Hebri-AI-Structure](https://github.com/HebrineX/Hebri-AI-Structure). Objetivo: contrato, trazabilidad y aprobaciones con 70-80% menos contexto frente a leer todo `.hebrinex`.

## Uso Diario

1. Validar `PROJECT_BINDING.yaml`.
2. Cargar kernel minimo: `session-pin`, `memory-registry`, `memory-routing`, `context-budget` y entrypoint.
3. Declarar contrato de sesion.
4. Elegir perfil minimo desde `orquestador/context-profiles.md`.
5. Pedir `SI` antes de efectos.
6. Ejecutar `auditor(profile: detractor_senior)` antes de implementar o escribir.
7. Cerrar con evidencia y `memory-closure-checklist.md` si hubo trabajo operativo.

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

Denegado por defecto: documentacion personal/local, memoria `complete/`, `CHANGELOG.md`, `README.md`, manifest, `init.sh`, prompts completos y todos los metodos.

## Bootstrap Seguro

Si un proyecto no tiene `.hebrinex`, no se opera con un harness externo. Se copia una fuente libre `source_template` a `<project_root>/.hebrinex/`, excluyendo materialmente documentacion personal/local, `.git/` y temporales, y luego se vincula como `bound`.

## Novedades Actuales

- CLI estable: `scripts/hebrinex.ps1` expone contrato versionado, markers parseables y validacion dedicada con `validate-cli.ps1`.
- Runtime enforcement ejecutable: `state-machine` bloquea transiciones invalidas y `agent-runtime` bloquea roles/capabilities no permitidas.
- CI oficial: GitHub Actions ejecuta validadores, auditores, drift checks,
  fixtures de migracion, fixtures negativos de seguridad, CLI estable e `init.sh`.
- Agent Contract System: los agentes existen por contratos YAML gobernados por el harness, no por prompts ni autoasignacion de IA.
- Seguridad AppSec verificable: permisos, write-scope, comandos, red, secretos, escalacion, logging y supply-chain se validan por registries.
- Servicio de migracion: rutas 0.8.10/0.9.0 -> 0.10.0 y 0.10.11 -> 0.11.0 con CheckOnly, Apply con backup, reporte y contrato post-migracion aplicado.
- Schemas y fixtures de validacion cubren contratos de agentes, seguridad y
  migracion con casos negativos.
- Command Gateway seguro: `hebrinex command -CheckOnly` clasifica comandos y
  `hebrinex command -Apply` ejecuta solo comandos read-only allowlisted, con
  timeout, root acotado, salida redactada y bloqueo deny-by-default.
- `init.sh` bloquea drift de version operativo fuera de `CHANGELOG.md`.
- `state.yaml` queda estructuralmente valido.
- Adapters y presets usan entrada minima: binding, session pin, registry, routing, budget y entrypoint.
- `memory-closure-checklist.md` obliga a cerrar local/daily/cycle/project antes de `done`.
- Bootstrap/migracion excluyen materialmente documentacion personal/local.
## Validacion Local

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/validate-harness.ps1 -RunNegativeTests
```

Esta validacion revisa manifest, schemas, presupuestos, exclusion de documentacion personal/local, migracion bound simulada y presets livianos por defecto. No reemplaza el contrato del harness; lo protege contra drift estructural.

## CI Oficial

El source template incluye `.github/workflows/ci.yml`. El job `Harness contract`
corre en `pull_request` y `push` a `main`:

- `scripts/validate-cli.ps1 -RunNegativeTests`
- `scripts/validate-harness.ps1 -RunNegativeTests`
- `scripts/audit-harness.ps1 -RunNegativeTests`
- `scripts/check-adapter-drift.ps1`
- fixtures/validadores de migracion
- fixtures/validadores negativos de seguridad
- `scripts/validate-state-machine.ps1 -RunNegativeTests`
- `scripts/validate-agent-runtime.ps1 -RunNegativeTests`
- `./init.sh`

Para bloquear merges, GitHub debe marcar `Harness contract` como required check
en branch protection.

## CLI Core

`scripts/hebrinex.ps1` es la entrada unica liviana y estable para operar scripts
del harness sin cargar todo el contexto. El contrato publico vive en
`orquestador/method/cli-contract.md` y se valida con `scripts/validate-cli.ps1`.

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 help
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 status
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 budget
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 preflight
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 validate -RunNegativeTests
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 audit -RunNegativeTests
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 migrate -CheckOnly
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 bootstrap -CheckOnly -ProjectRoot C:\path\project
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 update-bound -CheckOnly -ProjectRoot C:\path\project
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 list-bound-backups -CheckOnly -ProjectRoot C:\path\project
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 restore-bound -CheckOnly -ProjectRoot C:\path\project -BackupId <id>
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 command -CheckOnly -CommandText "Get-Content README.md"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 command -Apply -CommandText "Test-Path README.md"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 state-machine -FromState requested -ToState contract_resolved -Json
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/hebrinex.ps1 agent-runtime -RoleId implementer -Capability edit_approved_write_set -Json
```

La salida de `help` incluye `cli_contract_version=0.2`, `cli_status=stable` y
la lista cerrada de comandos publicos. `status`, `budget`, `preflight` y los
modos `-CheckOnly` no escriben. La CLI delega en validadores, migrador,
bootstrap/update/restore, Command Gateway, state machine y agent runtime existentes; no reemplaza
`state.yaml`, `registry.yaml`, gates ni evidencia.

`command -CheckOnly` no ejecuta el comando recibido. Solo clasifica contra
`orquestador/security/command-risk-registry.yaml`, redacciona secretos simples,
bloquea comandos desconocidos o compuestos y devuelve si requiere preflight/SI.
`command -Apply` conserva deny-by-default y solo ejecuta planes read-only
estrictos (`Get-Content`, `Select-String`, `Test-Path`, `Get-ChildItem`,
`git status --short`) dentro del root del harness. Con `-Json`, emite
`hebrinex.command_gateway.result` con decision, ejecucion y evidencia redactada.

`state-machine` lee `orquestador/agents/lifecycle-registry.yaml` y devuelve una decision `allow|block` sin escribir archivos. `agent-runtime` lee `agent-registry.yaml`, `capability-registry.yaml` y contratos de rol para bloquear capabilities faltantes o denegadas antes de operar.

## Detractor Senior

Antes de implementar, el leader debe pasar por auditor(profile: detractor_senior) o registrar bypass aprobado. El objetivo es llegar al mismo resultado con menos codigo, menos dependencias y menos abstracciones, sin sacrificar seguridad, datos, accesibilidad, contrato ni evidencia.

## Adapter portability

El contrato portable vive en orquestador/portability/core-skills.yaml y la cobertura por IA en orquestador/portability/adapter-matrix.yaml. Los adapters .yaml son declarativos y se verifican con scripts/check-adapter-drift.ps1.
