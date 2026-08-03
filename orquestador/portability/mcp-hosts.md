# Conexion del daemon MCP hebrinex por host

harness_version: "0.17.0"
Investigado: 2026-07-05 (WebSearch + docs oficiales; fuente citada por host).

El daemon MCP (`mcp/server.mjs`, stdio, Node >= 18) es la via AGNOSTICA del
harness: el mismo runtime de enforcement para cualquier host de IA con soporte
MCP. Jerarquia por host: feature nativa > tool del daemon MCP > simulacion por
prompt (fallback generico).

En proyectos bound el path del server es `.hebrinex/mcp/server.mjs`; en el repo
fuente es `mcp/server.mjs`. Los snippets usan la forma bound; ajustar si aplica.

## Claude Code

Archivo: `.mcp.json` en la raiz del proyecto (ya incluido en este repo).
Fuente: https://code.claude.com/docs/en/mcp (verificado 2026-07-05).

```json
{
  "mcpServers": {
    "hebrinex": {
      "command": "node",
      "args": [".hebrinex/mcp/server.mjs"]
    }
  }
}
```

## Cursor

Archivo: `.cursor/mcp.json` en el proyecto (o `~/.cursor/mcp.json` global).
El CLI de Cursor usa la misma configuracion que el editor.
Fuente: https://cursor.com/docs/mcp (verificado 2026-07-05).

```json
{
  "mcpServers": {
    "hebrinex": {
      "command": "node",
      "args": [".hebrinex/mcp/server.mjs"]
    }
  }
}
```

## Codex CLI (OpenAI)

Archivo: `~/.codex/config.toml` (global) o `.codex/config.toml` en el proyecto
(solo proyectos trusted). Formato TOML, seccion `[mcp_servers.<nombre>]`.
Fuente: https://developers.openai.com/codex/mcp (verificado 2026-07-05).

```toml
[mcp_servers.hebrinex]
command = "node"
args = [".hebrinex/mcp/server.mjs"]
```

## VS Code / GitHub Copilot

Archivo: `.vscode/mcp.json` en el workspace (o perfil de usuario). Ojo: la
clave top-level es `servers` (no `mcpServers`).
Fuente: https://code.visualstudio.com/docs/agents/reference/mcp-configuration
(verificado 2026-07-05).

```json
{
  "servers": {
    "hebrinex": {
      "type": "stdio",
      "command": "node",
      "args": [".hebrinex/mcp/server.mjs"]
    }
  }
}
```

## Gemini CLI

Archivo: `.gemini/settings.json` en el proyecto (o `~/.gemini/settings.json`
global), objeto top-level `mcpServers`.
Fuente: https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html
(verificado 2026-07-05).

```json
{
  "mcpServers": {
    "hebrinex": {
      "command": "node",
      "args": [".hebrinex/mcp/server.mjs"]
    }
  }
}
```

## Qwen Code

Archivo: `.qwen/settings.json` en el proyecto (o `~/.qwen/settings.json`
global), objeto `mcpServers` (mismo esquema que Gemini CLI, del que deriva).
Fuentes: https://qwenlm.github.io/qwen-code-docs/en/users/features/mcp/ y
https://qwenlm.github.io/qwen-code-docs/en/users/configuration/settings/
(verificado 2026-07-05).

```json
{
  "mcpServers": {
    "hebrinex": {
      "command": "node",
      "args": [".hebrinex/mcp/server.mjs"]
    }
  }
}
```

## DeepSeek

Sin via oficial verificada: el CLI oficial Deep Code
(https://api-docs.deepseek.com/quick_start/agent_integrations/deepcode,
verificado 2026-07-05) no documenta soporte MCP. Herramientas de terceros
(p. ej. DeepSeek-TUI, `~/.deepseek/mcp.json`) lo agregan, pero no son contrato
estable. Fallback: simulacion por prompt segun `AGENTS.md`.

## Verificacion post-conexion

En cualquier host, la prueba minima de que el daemon esta operativo:

1. Listar tools: deben aparecer las 13 (`run_command`, `preflight_approve`,
   `approval_check`, `session_contract`, `gate_check`, `memory_route`,
   `close_cycle_check`, `session_usage`, `role_assume`, `lock_acquire`,
   `lock_release`, `agent_audit`, `agent_review`).
2. Llamar `session_contract` (read-only): devuelve el contrato armado.
3. Llamar `run_command` con `git status --short`: decision=allow via gateway.
