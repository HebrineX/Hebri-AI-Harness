# Final Report Evidence Policy

Version: 0.17.0

Esta politica exige que todo cierre tenga links internos a la evidencia que lo sostiene.

## Cuando Aplica

Aplica antes de declarar `done`, `review` completo o cierre de fase/ciclo.

## Cross-links Obligatorios

El final report debe referenciar:

- gate log;
- audit trail;
- verification matrix si aplica;
- agent closure;
- memory closure checklist (`orquestador/sdd/progress/templates/memory-closure-checklist.md`);
- locks liberados o bloqueados;
- gaps abiertos;
- comandos o validaciones ejecutadas;
- archivos modificados.

## Regla

Un cierre sin referencias es un resumen, no evidencia. No puede usarse para declarar `done`.

## Bloqueos

Bloquear si:

- falta gate log;
- falta agent closure;
- falta cierre de memoria cuando hubo cambios de contrato, estado o contexto;
- hay locks abiertos no explicados;
- no hay evidencia de verificacion ni bloqueo documentado;
- el final report no permite reconstruir que paso.