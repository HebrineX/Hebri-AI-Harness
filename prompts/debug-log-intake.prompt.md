---
description: "Analizar logs/debug sin romper contrato ni ejecutar directo"
---

# Debug log intake

Usa `orquestador/entrypoints/debug-log-intake.md`.

No ejecutes comandos ni edites archivos por recibir un log. Primero:
- clasifica el log;
- separa hechos/inferencias;
- identifica read-set y comandos candidatos;
- presenta preflight si hace falta actuar.