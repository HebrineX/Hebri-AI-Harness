# Gemini Adapter

## Donde fijar instrucciones

- Instrucciones persistentes del proyecto si estan disponibles.
- Prompt inicial de sesion.
- `session-pin.md` para reentrada compacta.

## Reglas

- No asumir que Gemini conserva memoria entre sesiones.
- Usar `memory-routing.yaml` para decidir que cargar.
- Ante logs/debug, usar `debug-log-intake.md`.