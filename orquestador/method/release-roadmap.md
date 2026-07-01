# Release Roadmap

Version: 0.10.10

Este archivo fija el roadmap operativo luego de la reconciliacion de la linea
0.10.x. Los tags publicados no se reescriben ni se mueven; cualquier correccion
entra como release posterior.

## Linea 0.10.x

`0.10.7`, `0.10.8` y `0.10.10` quedaron publicados con mejoras de migracion
bound: update, restore e inventario de backups. Esas piezas son validas, pero
no completaban por si solas el hito de CI oficial definido para la linea 0.10.

`0.10.10` cierra ese desvio como release de realineacion:

- agrega GitHub Actions oficial;
- ejecuta validadores, auditores y drift checks;
- ejecuta fixtures de migracion;
- ejecuta fixtures negativos de seguridad;
- documenta que el PR debe bloquearse si falla contrato, agentes, seguridad o
  migracion.

## Cierre De 0.10.10

El release `0.10.10` esta cerrado solo si:

- `.github/workflows/ci.yml` existe en el source template;
- CI corre en `pull_request` y `push` a `main`;
- CI ejecuta `validate-harness.ps1 -RunNegativeTests`;
- CI ejecuta `audit-harness.ps1 -RunNegativeTests`;
- CI ejecuta `check-adapter-drift.ps1`;
- CI ejecuta `init.sh`;
- CI ejecuta fixtures/validadores de migracion;
- CI ejecuta fixtures/validadores negativos de seguridad;
- `validate-release.ps1` valida el workflow oficial en source template.

GitHub debe configurar el check `Harness contract` como requerido en branch
protection para que un PR no mergee si rompe contrato, agentes, seguridad o
migracion.

## 0.11.0 Enforcement Release

`0.11.0` no debe ser otro backfill de 0.10.x. Debe declararse recien cuando:

- la CLI sea estable;
- el Command Gateway funcione en modo operativo controlado;
- el runtime de agentes haga enforcement real de contratos y capabilities;
- la state machine bloquee transiciones invalidas;
- el migration engine tenga fixtures obligatorios;
- CI oficial este activo y validado.

La regla de corte es simple: `0.11.0` se publica despues de `0.10.10`, no antes,
y solo si el enforcement deja de ser declarativo.
