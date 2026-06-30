# Memory Layer Policy

Version: 0.10.0

## Objetivo

Definir como se cargan, actualizan, invalidan y cierran las capas de memoria sin romper el presupuesto de contexto.

| Capa | Autoridad | Default | Cierre requerido |
|---|---|---:|---:|
| local | session pin, active contract y foco | si | si |
| daily | contexto fresco del dia | si, si existe | si |
| cycle | state/registry/gates | si hay ciclo activo | si |
| project | decisiones estables | por perfil | si hubo decision estable |
| complete | evidencia historica | no | solo con aprobacion |

Reglas:
1. `memory-registry.yaml` decide capas activas.
2. `context-budget.yaml` decide cuanto se puede cargar.
3. La memoria completa requiere motivo, read-set y aprobacion.
4. La memoria no reemplaza evidence, gate logs, approvals, state ni registry.
5. Si una memoria contradice una fuente estructurada, detenerse y reportar conflicto.
6. Todo cierre operativo debe evaluar `orquestador/sdd/progress/templates/memory-closure-checklist.md`.
7. No promover logs/debug/transitorio a memoria de proyecto.