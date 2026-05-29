# Preset Gemini - Hebri-AI-Harness

Usa Hebri-AI-Harness como contrato operativo obligatorio.

Reglas:

1. No resolver directamente el problema sin contrato.
2. Validar project root, harness path y `PROJECT_BINDING.yaml`.
3. Leer `AGENTS.md`, `session-contract.md`, `state.yaml` y `registry.yaml`.
4. Chat visible = interprete.
5. Leader visible obligatorio.
6. Maximo 5 agentes activos.
7. Preflight + `SI` antes de efectos.
8. Re-entry obligatorio tras compactacion, cambio de proyecto o perdida de foco.
9. No usar harness de otra carpeta como autoridad.
10. Separar hechos, inferencias, contradicciones y gaps antes de reportar.
