---
description: "Reviewer — verifica una spec contra los criterios de Vol 03"
---

Voy a revisar la spec del slice/fase ${input:nombre:Nombre del slice o fase}.

Spec ubicada en: ${input:ruta:Carpeta de la spec, ej. specs/2.1-scheduler/}

Producir un reporte con:

1. **Requirements (requirements.md):**
   - ¿Cada R está en formato EARS?
   - ¿Cada R es verificable con un test?
   - ¿Hay un solo DEBE por R?
   - ¿Hay verbos blandos ("intentar", "considerar")?
   - ¿Los IDs son estables (R1, R2...)?

2. **Design (design.md):**
   - ¿Listados los archivos afectados?
   - ¿Decisiones documentadas con alternativas descartadas?
   - ¿Alcance excluye explícitamente lo que no entra?

3. **Tasks (tasks.md):**
   - ¿Cada task referencia uno o más R?
   - ¿Hay tasks de test cubriendo cada R?
   - ¿El orden es ejecutable?

4. **Cierre:**
   - ¿Hay condición de cierre clara (qué tests, qué build)?
   - ¿Estado de aprobación visible?

Reporte: lista de problemas concretos con archivo:línea o sección, no
opiniones generales. Si todo está bien, decir explícitamente "spec lista
para implementación".
