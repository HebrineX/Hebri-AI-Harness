# Copilot Adapter

## Donde fijar instrucciones

- `.github/copilot-instructions.md` si existe.
- Prompts reutilizables de `.github/prompts/`.
- `session-pin.md` del harness.

## Reglas

- Copilot instructions apuntan al harness, no duplican todo el contrato.
- No generar cambios amplios sin write-set declarado.
- Reentry por prompt corto cuando se pierda foco.