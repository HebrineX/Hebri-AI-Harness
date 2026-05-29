# Deploy Migration Policy

Version: 0.7.2

Esta politica evita documentar deploys, migraciones o cambios de entorno desde memoria parcial.

## Cuando Aplica

Aplica antes de editar o validar:

- `deploys/`
- scripts de despliegue
- migraciones de datos o infraestructura
- README de deploy
- changelog que resume deploys/migraciones
- reportes que declaran que un deploy quedo funcional

## Evidencia Minima

Antes de escribir narrativa historica, el leader debe reconstruir:

- entorno afectado;
- comando o pipeline usado;
- script, workflow o archivo de configuracion;
- version o commit asociado;
- resultado observado;
- rollback posible;
- gaps o pasos manuales.

## Regla

No alcanza con decir "se migro deploys". Hay que indicar que se movio, desde donde, hacia donde, con que evidencia y en que version/ciclo quedo registrado.

## Bloqueos

Bloquear si:

- hay deploy/migracion sin comando, script o evidencia;
- se mezclan pruebas de concepto con deploy productivo;
- no se distingue entorno local, staging, produccion o CI;
- falta rollback para un cambio riesgoso;
- el agente agrupa varias iteraciones de deploy como una sola sin evidencia.
