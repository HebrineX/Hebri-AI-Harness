# Release Roadmap

Version: 0.11.0

Este archivo fija el roadmap operativo luego de la reconciliacion de la linea
0.10.x. Los tags publicados no se reescriben ni se mueven; cualquier correccion
entra como release posterior.

## Linea 0.10.x

`0.10.7`, `0.10.8` y `0.10.9` quedaron publicados con mejoras de migracion
bound: update, restore e inventario de backups. Esas piezas son validas, pero
no completaban por si solas el hito de CI oficial definido para la linea 0.10.

`0.10.10` cierra el desvio de CI oficial:

- agrega GitHub Actions oficial;
- ejecuta validadores, auditores y drift checks;
- ejecuta fixtures de migracion;
- ejecuta fixtures negativos de seguridad;
- documenta que el PR debe bloquearse si falla contrato, agentes, seguridad o
  migracion.

`0.10.11` cierra el hito de CLI estable:

- documenta el contrato publico en `orquestador/method/cli-contract.md`;
- estabiliza `scripts/hebrinex.ps1` con markers parseables;
- agrega `scripts/validate-cli.ps1` como gate de release;
- integra la validacion CLI en `validate-harness`, `audit-harness`, `init.sh` y
  CI oficial.

## Cierre De 0.10.11

El release `0.10.11` esta cerrado cuando CI, CLI estable, Command Gateway,
validadores, auditores, fixtures de migracion y fixtures negativos de seguridad
pasan contra el source template publicado.

## 0.11.0 Enforcement Release

`0.11.0` es el salto de enforcement: deja de ser solo declarativo y agrega
puntos de decision ejecutables para lifecycle y capabilities.

El release `0.11.0` esta cerrado solo si:

- la CLI estable existe y publica contrato `0.2`;
- el Command Gateway funciona en modo operativo controlado;
- `scripts/state-machine.ps1` bloquea transiciones invalidas;
- `scripts/agent-runtime.ps1` bloquea roles/capabilities invalidas;
- `scripts/validate-state-machine.ps1 -RunNegativeTests` pasa;
- `scripts/validate-agent-runtime.ps1 -RunNegativeTests` pasa;
- el migration engine declara y valida `0.10.11 -> 0.11.0`;
- los fixtures positivos/negativos de runtime enforcement estan en manifest;
- CI oficial ejecuta CLI, harness, audit, migration, security, fixtures,
  state-machine, agent-runtime, drift e `init.sh`.

GitHub debe mantener el check `Harness contract` como required check en branch
protection para que un PR no mergee si rompe contrato, agentes, seguridad,
migracion, runtime enforcement o CLI.
