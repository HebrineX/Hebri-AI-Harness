# Agent Role Taxonomy

Este archivo define la taxonomia minima de agentes para Hebri-AI-Harness 0.8.4.

## Principio

```text
El sistema no escala creando mas agentes.
Escala con roles minimos, perfiles parametrizados, evidencia verificable y contradiccion tecnica controlada.
```

## Roles minimos

| Rol | Responsabilidad | No puede |
|---|---|---|
| `interpreter` | Comunica con el operador, traduce estado y pide `SI` | Coordinar de forma invisible |
| `leader` | Orquesta, decide, registra, bloquea o libera ciclos | Implementar |
| `executor` | Produce cambios dentro de scope aprobado | Aprobar su propio trabajo |
| `reviewer` | Revisa produccion contra spec, diff y evidencia | Editar codigo |
| `auditor` | Audita contrato, proceso, riesgos, sesgos y cumplimiento | Implementar o aprobar |
| `reporter` | Comunica resultados de forma clara y accionable | Cambiar veredicto o inventar evidencia |

## Perfiles iniciales

```yaml
auditor:
  profiles:
    - harness_compliance
    - cost
    - security
    - architecture
    - release
    - pipeline
    - detractor`n    - detractor_senior`nreporter:
  profiles:
    - operator
    - technical
    - executive
executor:
  profiles:
    - spec_author
    - implementer
    - worker
    - docs_writer
    - prompt_engineer
```

## Reglas

- No crear rol nuevo si alcanza con perfil de un rol existente.
- El perfil no cambia las prohibiciones del rol base.
- `auditor(profile: detractor)` solo objeta con evidencia o hipotesis verificable.`n- `auditor(profile: detractor_senior)` corre antes de implementar y valida solucion minima correcta.
- `reporter` no altera veredictos: solo comunica.
- El limite sigue siendo 5 agentes activos totales: 1 leader + 4 subagentes.
