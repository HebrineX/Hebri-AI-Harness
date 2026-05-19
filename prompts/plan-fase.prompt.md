---
description: "Planear una nueva fase antes de implementar"
---

Voy a arrancar la Fase ${input:numero:Número de fase} — ${input:nombre:Nombre de la fase}.

Contexto del proyecto:
${input:contexto:Stack, estado actual, fase anterior}

Producir en este orden:
1. Objetivo de la fase en una frase verificable.
2. Gaps de la fase anterior que esta fase resuelve.
3. Gaps nuevos que se difieren (con motivo).
4. requirements.md con formato EARS (R1, R2, R3...).
5. design.md con archivos afectados, decisiones y alternativas descartadas.
6. tasks.md con trazabilidad a requirements.
7. Criterio de cierre: qué tests deben pasar, qué build debe correr.

No implementar nada todavía. Solo la spec para aprobación.
