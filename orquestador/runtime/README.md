# Runtime Control Plane

El runtime es una vista operativa liviana. No es autoridad.

## Packaging central P06

El contrato instalado usa un `InstallRoot` inmutable con
`payload-manifest.json`, `release.json`, `packaging/runtime-layout.json` y
`bin/hebrinex.exe`. El payload se selecciona por entradas `file` exactas de
`orquestador/harness-manifest.txt` que ademas resuelven a `product` o
`template`; los builders y artefactos de desarrollo estan denegados.

El launcher x64 deriva `InstallRoot` desde su propia ubicacion, verifica
tamanos y SHA-256 y ejecuta el CLI `central1` mediante Windows PowerShell 5.1
del directorio de sistema. Argumentos y rutas se transfieren como datos Base64,
sin evaluacion ni busqueda en CWD. MCP permanece deshabilitado en el candidato
P06 y devuelve `OPTIONAL_FEATURE_MISSING`.

La evidencia local esta en `artifacts/p06/validation-report.json`. Esa ruta se
ignora en Git y no sustituye las pruebas de instalacion/ACL/VM de P07-P08.

Autoridad real:
- `.hebrinex/binding.json` para `central_instance`, o `PROJECT_BINDING.yaml` en layouts legacy/fuente.
- `orquestador/sdd/progress/state.yaml`.
- `orquestador/sdd/progress/registry.yaml`.
- gate logs, approvals, evidence y locks.

`active-session` puede ayudar al re-entry, status y presupuesto, pero no puede declarar `done`, aprobar acciones ni reemplazar evidencia.
Si contradice estado/registry, gana estado/registry y se reconstruye runtime.

## Enforcement 0.17.0

0.12.0 agrega decisiones ejecutables read-only:

- `scripts/state-machine.ps1` lee `orquestador/agents/lifecycle-registry.yaml` y bloquea transiciones invalidas.
- `scripts/agent-runtime.ps1` lee agent registry, capability registry y contratos de rol para bloquear capabilities faltantes o denegadas.

Estas decisiones no reemplazan state, registry ni evidencia. Sirven como gate operativo antes de instanciar un agente, cambiar lifecycle o permitir una capability.

## Project service central

La interfaz versionada `central1`, sus autoridades, flujo plan/SI/APR2/Apply,
errores y recuperacion se documentan en [project-service-central1.md](project-service-central1.md).

La conversion de copias completas legacy, su clasificacion, snapshots SHA-256,
matriz soportada y restore se documentan en
[legacy-migration-central1.md](legacy-migration-central1.md).
