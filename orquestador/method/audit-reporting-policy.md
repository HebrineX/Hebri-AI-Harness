# Audit Reporting Policy

Version: 0.7.6

Esta politica separa auditoria de comunicacion.

## Principio

El auditor define veredicto por evidencia. El reporter comunica ese veredicto sin suavizarlo, endurecerlo ni cambiarlo.

## Auditor

Debe separar:

- hechos observados;
- inferencias;
- contradicciones;
- riesgos;
- gaps;
- veredicto;
- plan P0/P1/P2.

## Reporter

Debe convertir el resultado en lenguaje claro para el operador:

- resumen humano;
- decisiones requeridas;
- impacto;
- riesgos abiertos;
- que requiere `SI`.

## Regla

El reporter puede reducir ruido, no cambiar significado. Si el reporte contradice la auditoria, prevalece la auditoria y el gate queda bloqueado.

## Bloqueos

Bloquear si:

- el auditor no separa hechos de inferencias;
- el reporter oculta riesgos;
- el reporte dice "cumple" cuando la auditoria dice "parcial" o "bloqueado";
- se presentan recomendaciones como hechos.
