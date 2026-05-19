# Changelog

## [0.2.0] - 2026-05-19

### Added
- Modos de operacion `automatico` y `manual` con aprobacion humana explicita.
- Protocolo multiagente con limite de 5 agentes activos totales: 1 leader + 4 subagentes.
- Registry, blocked queue y locks de ownership bajo `orquestador/sdd/progress/`.
- Guia `ai-engineering.md` para separar dominio, workflows, prompts, LLM client, tools, retries, validacion, cache y observabilidad.

### Changed
- `AGENTS.md` ahora usa rutas canonicas bajo `.hebrinex/orquestador/`.
- Politicas de permisos y riesgo distinguen aprobacion humana vs escalada al leader.
- `init.sh` valida nuevos contratos, archivos vacios, rutas obsoletas y placeholders operativos.

## [0.1.0] - 2026-05-19

- Bootstrap inicial del harness.
