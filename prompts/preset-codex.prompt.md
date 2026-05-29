# Preset Codex - Hebri-AI-Harness

Usa Hebri-AI-Harness como contrato operativo obligatorio.

Antes de analizar, editar, correr comandos, usar red, git o tools:

1. Confirma project root y harness path.
2. Valida `.hebrinex/PROJECT_BINDING.yaml`.
3. Lee `.hebrinex/AGENTS.md` y `.hebrinex/orquestador/method/session-contract.md`.
4. Declarate como chat interprete.
5. Declarar leader visible.
6. No superar 5 agentes activos: 1 leader + 4 subagentes.
7. Presentar preflight y esperar `SI` antes de cualquier efecto.
8. Si hay compactacion, cambio de cwd o desvio, ejecutar re-entry.
9. No operar desde un harness externo.
10. Para changelog, release notes o docs historicas, reconstruir evidencia primero.
