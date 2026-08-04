# Provider Screen Contract

Version: 0.17.0
Contract version: 0.1
Status: experimental

`scripts/hebrinex-screen.ps1` is a local provider screen for Hebri-AI-Harness. It
helps an operator see how Codex, Claude Code, Qwen and other adapters connect to
the harness without making MCP mandatory and without storing subscriptions,
tokens or API keys.

## Scope

The provider screen is an informational and diagnostic layer over the existing
harness core:

- reads `PROJECT_BINDING.yaml`, `HARNESS_VERSION`, adapter YAML files, the
  adapter registry and `mcp/agents-backend.yaml`;
- lists providers and their instruction surfaces;
- shows the MCP registration target declared by each adapter;
- checks whether known provider CLIs are present in `PATH`;
- explains that authentication belongs to each provider CLI/API;
- reports `writes=false` for the default commands.

It does not replace `scripts/hebrinex.ps1`, `state.yaml`, `registry.yaml`,
approvals, gates, locks, evidence or the MCP daemon.

## Commands

The experimental command set is:

- `menu`
- `providers`
- `provider -Provider <adapter_id>`
- `guide -Provider <adapter_id>`
- `doctor`

These commands are outside the stable CLI contract `0.5`. They must not be added
to `scripts/hebrinex.ps1` until the public CLI contract is intentionally bumped.

## Provider Boundary

The harness must not store provider subscriptions or secrets. A subscription is
considered external state owned by the vendor CLI, local credential manager,
environment variable, or account session.

Allowed local hints:

- provider CLI presence in `PATH`;
- adapter maturity;
- persistent instruction file;
- MCP configuration file path;
- local override status for `mcp/agents-backend.local.yaml`.

Denied by default:

- writing API keys;
- copying tokens into the repo;
- testing paid model calls as a default diagnostic;
- assuming MCP is connected before registration is verified.

## MCP Relationship

MCP is optional. If MCP is connected, it can expose harness tools and agent role
backends. If MCP is absent or broken, the harness still operates through the
adapter prompt, visible role simulation, preflight/SI and filesystem evidence.

## Validation

Minimal validation for this experimental screen:

```powershell
.\scripts\hebrinex-screen.ps1 providers
.\scripts\hebrinex-screen.ps1 provider -Provider codex
.\scripts\hebrinex-screen.ps1 provider -Provider claude-code
.\scripts\hebrinex-screen.ps1 doctor
```

The stable harness validation must continue to pass after adding this screen.
