# Qwen Adapter

## Donde fijar instrucciones

- System/developer prompt disponible en la herramienta usada.
- Prompt inicial si no hay memoria persistente.
- `session-pin.md` como contrato compacto.

## Reglas

- Tratar memoria de herramienta como no confiable.
- Roles simulados si no hay subagentes reales.
- Reentry liviano ante cambio de contexto.