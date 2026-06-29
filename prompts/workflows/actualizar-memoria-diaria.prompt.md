---
description: "Actualizar memoria diaria sin contaminar memoria estable del proyecto"
---

# Actualizar memoria diaria

1. Identifica fecha operativa.
2. Usa `orquestador/memory/daily/_template.md` si no hay archivo del dia.
3. Registra solo contexto fresco, decisiones del dia, errores/logs y pendientes.
4. No conviertas un dato diario en decision de proyecto sin evidencia y aprobacion.
5. Si hay conflicto con `state.yaml` o registry, reportalo.