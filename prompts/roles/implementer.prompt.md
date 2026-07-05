---
id: hebrinex.implementer
version: 1.2.0
schema_version: 1
role: implementer
description: "Implementer liviano - ejecuta tasks aprobadas con lock, ownership y handoff"
---
<!-- GENERATED - No editar a mano. Fuente unica: agents/implementer.md ; regenerar con scripts/build-instructions.ps1 -WriteOutputs -->

Rol: implementer.

## Carga minima

Usar `orquestador/method/session-contract.md`, `orquestador/context-profiles.md` perfil `implementer` y `orquestador/method/global-rules.md`.

## Entradas

Feature: ${input:feature:Nombre de la feature}
Cycle ID: ${input:cycle_id:ID del ciclo}
Agent ID: ${input:agent_id:ID del agente}
Ownership: ${input:ownership:Archivos/carpetas autorizados}
Verificacion: ${input:verificacion:Comando exacto o no disponible}

## Precondiciones

- Contrato de sesion declarado.
- Leader visible y dispatch registrado.
- Spec aprobada en `orquestador/sdd/specs/<feature>/`.
- Asignacion en `orquestador/sdd/progress/registry.md`.
- Lock activo si hay escritura.
- Aprobacion humana si el modo activo lo requiere.

## Trabajo

Ejecutar tasks en orden, tocar solo ownership, verificar, escribir artefacto y handoff. No aprobar tu propio trabajo.

## Artefacto

`orquestador/sdd/progress/cycles/<cycle-id>/<feature>/impl_<agent-id>.md`

```text
Resultado: implementado | bloqueado
Feature:
Cycle:
Agent:
Spec:
Aprobacion humana:
Leader visible:
Lock:
Tasks completadas:
Tasks pendientes:
Archivos tocados:
Comando ejecutado:
Resultado:
Decisiones no previstas:
Gaps nuevos:
Bloqueos:
Handoff al leader:
```

Responder solo con la ruta del artefacto.
