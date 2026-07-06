# MCP Dogfood — Fase 7 (0.15.0)

Log de evidencia del uso real del daemon MCP `hebrinex` durante la fase 7
(hooks faltantes + enforcement restante). Formato por entrada: tool, resultado,
latencia percibida, fricciones/bugs.

## Sesion

- Fecha: 2026-07-05
- Cliente: Claude Code (Fable 5), MCP conectado via `.mcp.json`
- Alcance: implementacion de `hebrinex lock`, writeguard, hooks Stop/PreCompact,
  rate limit del gateway e identidad de rol MCP.

## Registro de uso

### 1. session_contract (inicio de sesion)

- Resultado: OK al primer intento. Contrato correcto (source_template / 0.14.0,
  budget leader_light 2477/2600 ok, ciclo pending, 0 locks).
- Latencia percibida: baja.
- Friccion: ninguna.

### 2. gate_check (cierre de fase, working tree con ~116 archivos tocados)

- Resultado: OK. Clasificacion correcta del scope del release: G5B (required,
  disparado por CHANGELOG/HARNESS_VERSION/README/manifest), G5C (migracion:
  ruta 0.14.0-to-0.15.0 + registry + contrato), G5D (drift de referencias por el
  bump masivo de adapters/method/prompts), G5G y G5I. G5E/G5F/G5H correctamente
  en applies=false.
- Latencia percibida: baja incluso con 116 archivos.
- Friccion: ninguna. La lista matched_files por gate es directamente accionable.

### 3. close_cycle_check (cierre de fase)

- Resultado: pass=false con gaps honestos: HANDOFF-fase7.md abierto (correcto:
  todavia estaba trabajando), last_final_report vacio y verification.status
  not_defined. open_locks/open_agents en 0 (los locks de prueba se liberaron y
  limpiaron bien).
- Latencia percibida: baja.
- Friccion (menor, heredada de fase 6): en este repo source_template que opera
  "release-style" sin ciclo SDD formal, los gaps last_final_report /
  verification.status aparecen siempre; son senal util pero no distinguen
  "ciclo sin cerrar" de "no hay ciclo formal abierto".

### 4. Tools nuevas (lock_acquire, lock_release, role_assume)

- NO disponibles en esta sesion via MCP: el daemon se carga al inicio de la
  sesion con el codigo anterior (0.14.0) y las tools nuevas requieren reiniciar
  el proceso/servidor MCP. Friccion estructural conocida de MCP stdio, no un bug.
- Cobertura equivalente: `mcp/smoke.mjs` (cliente MCP real contra el server
  nuevo) ejercita las 11 tools: lock_acquire (ok + lock_conflict), lock_release
  (ok + lock_not_found), role_assume (unknown_role rechazado; reviewer bloqueado
  con role_capability_blocked en lock_acquire; implementer ok con owner=rol del
  daemon; run_command con role_enforced=true). 21/21 checks OK.

### 5. run_command (no usado para consultas en esta fase)

- Motivo: friccion documentada en fase 6 sigue vigente en 0.15.0 — el allowlist
  del gateway no cubre los comandos read-only del propio CLI (`hebrinex status`,
  `usage`, `lock -List` via pwsh), asi que las consultas y validadores corrieron
  por Bash directo (permitido por las reglas del repo para validadores).
- Pendiente propuesto para 0.16.x: plan seguro allowlisteado para
  `scripts/hebrinex.ps1` con subcomandos read-only (status|budget|usage|help|
  lock -List).

## Veredicto de tools usadas

- session_contract: solida, sin cambios necesarios.
- gate_check: solida; escala bien a un scope de release completo.
- close_cycle_check: correcta y honesta; mejora candidata: distinguir "sin ciclo
  formal" de "ciclo abierto sin cerrar".
- lock_acquire/lock_release/role_assume: verificadas via smoke MCP real (21
  checks); quedan pendientes de dogfood en vivo en la proxima sesion (el daemon
  ya expondra el codigo 0.15.0 al reiniciar).
