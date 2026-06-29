---
description: "Cerrar formalmente una fase con evidencia"
---

Voy a cerrar la Fase ${input:numero:Número de fase}.

Verificar y reportar:
1. ¿Todos los tests pasan? → correr el comando de verificación y mostrar resultado.
2. ¿El build de release corre limpio?
3. ¿Todos los requirements tienen al menos un test?
4. ¿Los gaps diferidos están registrados en PROGRESS.md con motivo?
5. ¿La documentación refleja el estado actual?
6. ¿El tag de versión está creado (si corresponde)?

Producir:
- Resumen de cierre con evidencia concreta (N tests passed, build OK).
- Lista de gaps diferidos a la siguiente fase.
- Próximos pasos sugeridos.
