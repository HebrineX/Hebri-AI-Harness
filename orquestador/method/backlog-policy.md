# Backlog Policy

Version: 0.7.5

Esta politica ordena P0/P1/P2 por impacto, bloqueo y dependencia, no por preferencia del agente.

## Clasificacion

| Nivel | Significado |
|---|---|
| P0 | Bloquea uso seguro, cierre, evidencia, integridad o contrato operativo |
| P1 | Mejora importante, reduce riesgo o deuda, pero no bloquea el flujo actual |
| P2 | Conveniencia, automatizacion futura o mejora opcional |

## Criterios

Cada item debe declarar:

- problema concreto;
- impacto;
- dependencia;
- evidencia;
- criterio de promocion;
- criterio de cierre.

## Regla

No se promueve un item por intuicion. Se promueve porque bloquea, reduce riesgo relevante o habilita otra fase.

## Bloqueos

Bloquear si:

- se mezclan P0/P1/P2 sin criterio;
- un item P0 no tiene condicion de cierre;
- un item P2 se implementa antes que un P0 bloqueante sin justificacion;
- el roadmap no distingue implementado, candidato y diferido.
