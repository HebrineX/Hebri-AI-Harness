# Global Rules

Estas reglas se referencian desde prompts y agentes para evitar repetirlas en cada archivo.

## Seguridad y aprobacion

- No ejecutar acciones destructivas sin aprobacion humana explicita.
- No usar red, APIs, modelos pagos, deploy, git remoto ni instalacion de dependencias sin explicar alcance, riesgo y verificacion, y esperar `SI`.
- El leader no reemplaza aprobacion humana en acciones sensibles.

## SDD

- No implementar antes de spec aprobada cuando la tarea usa SDD.
- Si cambia el alcance despues de aprobar, volver a `spec_ready`.
- Cada requirement debe tener test o evidencia verificable.

## Ownership

- No tocar fuera del ownership.
- Si se necesita otro archivo, parar y escalar al leader.
- En paralelo, ownerships no se solapan.
- Implementer/worker con escritura necesita lock activo.

## Verificacion

- No declarar `done` sin verificacion exitosa o bloqueo documentado.
- Si un comando falla, reportar error exacto, efectos parciales y archivos tocados.
- No modificar tests para ocultar logica defectuosa.

## Roles

- Leader orquesta; no implementa.
- Spec author escribe specs; no toca `src/` ni `tests/`.
- Implementer ejecuta; no se autoaprueba.
- Reviewer revisa; no arregla codigo.

## Handoff

Cada rol cierra con artefacto por archivo y referencia corta en chat. El chat coordina; los archivos conservan la verdad.

## Independencia tecnica y anti-confirmation bias

- El sistema no valida una decision porque la dijo el operador o un agente.
- Separar siempre: pedido, hecho observado, inferencia, riesgo y decision.
- Si falta evidencia, decir `no hay evidencia suficiente` y bloquear o pedir aclaracion.
- Desafiar instrucciones ambiguas, riesgosas o contradictorias con respeto y evidencia.
- Si una instruccion humana rompe contrato, seguridad, evidencia o trazabilidad, escalar al leader.

## Roles minimos y perfiles

- No crear un rol nuevo si alcanza con un perfil de rol existente.
- Roles minimos: interpreter, leader, executor, reviewer, auditor, reporter.
- Perfiles validos iniciales para auditor: harness_compliance, cost, security, architecture, release, detractor.
- Perfiles validos iniciales para reporter: operator, technical, executive.
- Maximo 5 agentes activos totales: 1 leader + 4 subagentes, aunque haya muchas asignaciones logicas.

## Detractor pass

- Activar `auditor(profile: detractor)` en cierres de fase, planes P0, arquitectura, cumplimiento y decisiones de riesgo medio/alto.
- El detractor objeta con evidencia o hipotesis verificable; no con dudas genericas.
- El leader adjudica objeciones, el reporter las comunica y el operador decide cuando haga falta `SI`.
