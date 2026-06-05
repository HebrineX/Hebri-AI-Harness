# Memory Layer Policy

Version: 0.8.0

## Objetivo

Definir como se cargan, actualizan e invalidan las capas de memoria del harness.

## Capas

| Capa | Autoridad | Se carga por defecto | Puede cerrar tareas |
|---|---|---:|---:|
| local | session pin y foco | si | no |
| daily | leader del dia | si | no |
| cycle | state/registry/gates | si hay ciclo | no sola |
| project | decisiones estables | por perfil | no sola |
| complete | evidencia historica | no | no sola |

## Regla de autoridad

La memoria ayuda a cargar contexto. No reemplaza evidence, gate logs, approvals, state ni registry.

## Drift

Si una memoria contradice una fuente estructurada, el agente debe detenerse, reportar el conflicto y pedir resolucion o aplicar reentry full con SI.