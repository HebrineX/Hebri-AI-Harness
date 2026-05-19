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
