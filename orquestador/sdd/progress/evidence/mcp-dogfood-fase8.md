# Dogfood MCP - Fase 8 (release 0.16.0)

Registro de uso real de las tools mcp__hebrinex__* durante la fase 8, con
fricciones y bugs encontrados. Veredicto final al cierre de la fase.

## Sesion 1 (2026-07-05)

- `session_contract` (inicio): OK. Contrato armado, budget leader_light
  2477/2600 ok. Binding source_template / 0.15.0.
- `role_assume(implementer)`: OK. status=assumed, contract_ref correcto.
- `preflight_approve` (backend codex para demo): OK, APR-20260706T013227Z-d20ab0
  registrado con TTL 240m.
- `agent_audit` (NUEVA, via cliente MCP real, backend codex-cli): OK.
  Plan "libreria yaml para parsear YAML" -> Veredicto: bloquear, con salida
  completa del rol detractor (16.4s). verdict_parsed=true.
- `agent_review` (NUEVA, via cliente MCP real, backend codex-cli): OK.
  Diff validate-mcp + acceptance criteria -> Resultado/Decision: bloqueado
  (pidio evidencia de verificacion; comportamiento estricto correcto del rol).
- Friccion 1: ni `claude` ni `codex` estaban en PATH; el Codex CLI vive dentro
  de la app de OpenAI (AppData\Local\OpenAI\Codex\bin\...). Se resolvio con
  mcp/agents-backend.local.yaml (override por maquina, git-ignored) - feature
  agregada a la fase por necesidad real.
- Friccion 2 (menor): la salida de agent_review no siempre arranca con
  "Resultado:"; el parser acepta Resultado|Decision y por eso parseo bien.
- Friccion 3 (proyeccion nativa): Claude Code carga el registro de subagentes
  al inicio de la sesion y NO recarga .claude/agents/ mid-session. El template
  quedo instalado y verificado (frontmatter read-only, contenido generado),
  pero la invocacion real host-enforceada requiere sesion nueva. Verificado
  dos veces: "Agent type 'auditor-detractor' not found".

- `gate_check` (cierre): OK. 122 archivos tocados clasificados; aplican
  G5B (release), G5C (migracion), G5D (drift referencias), G5G (policy tocada
  solo por bump) y G5I (memoria, solo bump de version). Sin falsos negativos
  detectados.

## Veredicto

Las tools del daemon funcionaron para operar la fase completa:
session_contract (contrato + budget real), role_assume (implementer),
preflight_approve (envelope para el backend codex), gate_check (clasificacion
correcta del scope del release) y las NUEVAS agent_audit/agent_review
(veredictos reales via codex-cli read-only). close_cycle_check se uso como
guard de cierre (bloquea con handoff abierto, comportamiento esperado).
Bugs encontrados: ninguno en las tools existentes. Fricciones: (1) CLIs de
backend fuera de PATH -> se resolvio con agents-backend.local.yaml (feature
nueva), (2) formato de salida del reviewer no determinista -> parser acepta
Resultado|Decision, (3) Claude Code no recarga .claude/agents/ mid-session ->
la demo nativa host-enforceada requiere sesion nueva.
