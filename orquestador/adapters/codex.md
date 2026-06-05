# Codex Adapter

## Donde fijar instrucciones

- Instrucciones personalizadas / detalles de Codex.
- `AGENTS.md` del repo activo.
- `.hebrinex/orquestador/memory/local/session-pin.md` como rehidratacion compacta.

## Reglas

- Usar tools solo despues de preflight si tienen efecto.
- Reportar como interprete; leader visible en texto o artefacto.
- Si hay compaction, ejecutar `compactation-recovery.md`.
- No depender de memoria del hilo para approvals.

## Primer arranque

Leer `first-message.md` y declarar capas cargadas.