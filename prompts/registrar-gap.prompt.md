---
description: "Registrar formalmente un gap detectado en PROGRESS.md"
---

Detecté un gap durante el trabajo. Necesito que quede registrado.

Título corto: ${input:titulo:Una frase}

Capa: ${input:capa:Dev / Testing / Docs / Security / Infra / DevOps}

Descripción: ${input:descripcion:Qué falta o está incompleto}

Contexto: ${input:contexto:Por qué existe este gap}

Motivo de no resolverlo ahora: ${input:motivo:Por qué se difiere}

Destino sugerido: ${input:destino:Fase X o "Sin asignar"}

Producir:

1. Bloque markdown con el formato de gap de Vol 06.
2. Actualización propuesta del bloque "Gaps activos" en `PROGRESS.md`.
3. Si el gap aparece en la biblioteca por capa (Vol 06), referenciar el ID
   (ej. D-03, T-04).

No tocar otros archivos. Solo proponer el registro.
