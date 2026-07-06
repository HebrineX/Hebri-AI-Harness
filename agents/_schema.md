# Agent File Schema

Version: 0.16.0

Todo archivo en `agents/` debe seguir esta estructura minima. El objetivo es que cada IA lea roles de forma estable y no reinvente permisos.

## Campos Obligatorios

```text
# [Nombre]
Tipo:
Profile(s):
Objetivo:
Cuando se activa:
Entrada minima:
Lectura permitida:
Lectura prohibida por defecto:
Puede:
No puede:
Gates que debe cumplir:
Salida obligatoria:
Criterios de bloqueo:
Handoff:
Presupuesto de contexto:
```

## Reglas

- Un agente no cambia las prohibiciones de su rol base.
- Un perfil no crea un rol nuevo.
- Todo agente que pueda bloquear debe explicar evidencia o hipotesis verificable.
- Todo agente que termine debe dejar handoff o cierre.
- Si el host no soporta subagentes reales, el chat simula el rol explicitamente.