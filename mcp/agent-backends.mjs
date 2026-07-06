// Backends de ejecucion para los agentes de rol del daemon MCP (agent_audit /
// agent_review). Un backend = una entrada en BACKENDS que recibe
// {prompt, timeoutMs, config} y devuelve {status, raw, ...}; el veredicto lo
// parsea el caller sobre `raw` segun el formato de salida del rol.
//
// Contrato de seguridad: el comando del backend es un string FIJO definido en
// mcp/agents-backend.yaml; el prompt viaja por stdin, nunca por argv ni
// interpolado en el shell. Cada backend debe correr read-only:
// - claude-cli: `claude -p` con --allowedTools limitado a Read,Grep,Glob.
// - codex-cli: `codex exec --sandbox read-only -`.
// Para agregar un backend (ej. ollama): entrada en agents-backend.yaml +
// entrada en BACKENDS de abajo. Las tools del server no se tocan.

import { spawn } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const DEFAULT_TIMEOUT_SECONDS = 240;

// --- Config (mcp/agents-backend.yaml, YAML plano sin dependencia externa) ----

function readTextFile(path) {
  if (!existsSync(path)) return null;
  return readFileSync(path, 'utf8').replace(/^﻿/, '').replace(/\r\n/g, '\n');
}

function getScalar(text, key) {
  if (!text) return '';
  const re = new RegExp(`^${key}:\\s*(.*)$`);
  for (const line of text.split('\n')) {
    const match = line.match(re);
    if (match) return match[1].trim().replace(/^"(.*)"$/s, '$1').replace(/^'(.*)'$/s, '$1');
  }
  return '';
}

// Entradas de `backends:` con forma:
//   <id>:
//     command: ...
//     output: ...
function parseBackendEntries(text) {
  const entries = {};
  if (!text) return entries;
  const lines = text.split('\n');
  let inBackends = false;
  let currentId = '';
  for (const line of lines) {
    if (/^backends:\s*$/.test(line)) { inBackends = true; continue; }
    if (inBackends && /^[A-Za-z0-9_.-]+:/.test(line)) { inBackends = false; currentId = ''; }
    if (!inBackends) continue;
    const idMatch = line.match(/^  ([A-Za-z0-9-]+):\s*$/);
    if (idMatch) { currentId = idMatch[1]; entries[currentId] = {}; continue; }
    const fieldMatch = line.match(/^    ([A-Za-z_]+):\s*(.+?)\s*$/);
    if (fieldMatch && currentId) {
      entries[currentId][fieldMatch[1]] = fieldMatch[2].replace(/^"(.*)"$/s, '$1').replace(/^'(.*)'$/s, '$1');
    }
  }
  return entries;
}

// mcp/agents-backend.local.yaml (git-ignored) pisa la config versionada:
// backend/timeout_seconds y comandos por backend son por-maquina (rutas
// absolutas de CLIs, eleccion de backend disponible en ese host).
export function loadAgentsBackendConfig(root) {
  const configPath = join(root, 'mcp/agents-backend.yaml');
  const text = readTextFile(configPath);
  if (!text) {
    return { exists: false, configPath, defaultBackend: 'none', timeoutSeconds: DEFAULT_TIMEOUT_SECONDS, backends: {} };
  }
  const config = {
    exists: true,
    configPath,
    defaultBackend: getScalar(text, 'backend') || 'none',
    timeoutSeconds: Number(getScalar(text, 'timeout_seconds')) || DEFAULT_TIMEOUT_SECONDS,
    backends: parseBackendEntries(text),
  };
  const localText = readTextFile(join(root, 'mcp/agents-backend.local.yaml'));
  if (localText) {
    const localBackend = getScalar(localText, 'backend');
    if (localBackend) config.defaultBackend = localBackend;
    const localTimeout = Number(getScalar(localText, 'timeout_seconds'));
    if (localTimeout) config.timeoutSeconds = localTimeout;
    const localEntries = parseBackendEntries(localText);
    for (const [id, entry] of Object.entries(localEntries)) {
      config.backends[id] = { ...config.backends[id], ...entry };
    }
    config.localOverride = 'mcp/agents-backend.local.yaml';
  }
  return config;
}

// --- Ejecucion --------------------------------------------------------------

function runFixedCommandWithStdin(command, prompt, { cwd, timeoutMs }) {
  return new Promise((resolvePromise) => {
    let child;
    try {
      // shell:true con comando FIJO de la config (sin texto del caller); el
      // prompt entra por stdin. Necesario en Windows para resolver shims .cmd.
      child = spawn(command, { cwd, shell: true, windowsHide: true });
    } catch (error) {
      resolvePromise({ exitCode: 127, stdout: '', stderr: `cannot spawn backend: ${error.message}`, timedOut: false });
      return;
    }
    let stdout = '';
    let stderr = '';
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      try {
        if (process.platform === 'win32') {
          spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'], { stdio: 'ignore' });
        } else {
          child.kill('SIGKILL');
        }
      } catch { /* best effort */ }
      resolvePromise({ exitCode: 124, stdout, stderr: `${stderr}\n[agent-backend] timeout after ${timeoutMs}ms`.trim(), timedOut: true });
    }, timeoutMs);
    child.stdout.on('data', (chunk) => { stdout += chunk.toString('utf8'); });
    child.stderr.on('data', (chunk) => { stderr += chunk.toString('utf8'); });
    child.on('error', (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolvePromise({ exitCode: 127, stdout, stderr: `cannot spawn backend: ${error.message}`, timedOut: false });
    });
    child.on('close', (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolvePromise({ exitCode: code == null ? 1 : code, stdout, stderr, timedOut: false });
    });
    child.stdin.on('error', () => { /* el proceso murio antes de leer stdin */ });
    child.stdin.write(prompt, 'utf8');
    child.stdin.end();
  });
}

// `claude -p --output-format json` devuelve un objeto con el texto final en
// `result`; si no parsea, se usa stdout crudo como raw.
function extractClaudeJsonResult(stdout) {
  try {
    const parsed = JSON.parse(stdout);
    if (parsed && typeof parsed.result === 'string') {
      return { raw: parsed.result, isError: parsed.is_error === true, meta: { total_cost_usd: parsed.total_cost_usd ?? null, num_turns: parsed.num_turns ?? null } };
    }
  } catch { /* fallthrough */ }
  return { raw: stdout, isError: false, meta: {} };
}

const BACKENDS = {
  'claude-cli': {
    id: 'claude-cli',
    defaultCommand: 'claude -p --output-format json --allowedTools "Read,Grep,Glob"',
    async run({ prompt, command, cwd, timeoutMs }) {
      const result = await runFixedCommandWithStdin(command || this.defaultCommand, prompt, { cwd, timeoutMs });
      if (result.timedOut) return { status: 'timeout', raw: result.stdout, stderr: result.stderr, exitCode: result.exitCode };
      if (result.exitCode === 127) return { status: 'unavailable', raw: '', stderr: result.stderr, exitCode: result.exitCode };
      const extracted = extractClaudeJsonResult(result.stdout);
      if (result.exitCode !== 0 || extracted.isError) {
        return { status: 'failed', raw: extracted.raw, stderr: result.stderr, exitCode: result.exitCode, meta: extracted.meta };
      }
      return { status: 'ok', raw: extracted.raw, stderr: result.stderr, exitCode: result.exitCode, meta: extracted.meta };
    },
  },
  'codex-cli': {
    id: 'codex-cli',
    defaultCommand: 'codex exec --sandbox read-only -',
    async run({ prompt, command, cwd, timeoutMs }) {
      const result = await runFixedCommandWithStdin(command || this.defaultCommand, prompt, { cwd, timeoutMs });
      if (result.timedOut) return { status: 'timeout', raw: result.stdout, stderr: result.stderr, exitCode: result.exitCode };
      if (result.exitCode === 127) return { status: 'unavailable', raw: '', stderr: result.stderr, exitCode: result.exitCode };
      if (result.exitCode !== 0) return { status: 'failed', raw: result.stdout, stderr: result.stderr, exitCode: result.exitCode };
      return { status: 'ok', raw: result.stdout, stderr: result.stderr, exitCode: result.exitCode, meta: {} };
    },
  },
};

export function listKnownBackends() {
  return Object.keys(BACKENDS);
}

// Punto de entrada de las tools: resuelve backend (config o override del
// caller), corre el comando fijo con el prompt por stdin y devuelve
// {status, backend, raw, ...}. status: ok | not_configured | unknown_backend |
// unavailable | timeout | failed.
export async function runRoleAgent({ root, prompt, backendOverride, timeoutSecondsOverride }) {
  const config = loadAgentsBackendConfig(root);
  const backendId = (backendOverride || config.defaultBackend || 'none').trim();
  const notConfigured = {
    status: 'not_configured',
    backend: backendId,
    config_path: 'mcp/agents-backend.yaml',
    how_to_configure: [
      'Editar mcp/agents-backend.yaml y setear `backend: claude-cli` (requiere Claude Code CLI en PATH)',
      'o `backend: codex-cli` (requiere OpenAI Codex CLI en PATH).',
      'Fallback sin backend: correr el rol manualmente con el prompt de agents/<rol>.md (simulacion trazable).',
    ].join(' '),
  };
  if (backendId === 'none' || backendId === '') return notConfigured;
  const backend = BACKENDS[backendId];
  if (!backend) {
    return { status: 'unknown_backend', backend: backendId, known_backends: listKnownBackends(), config_path: 'mcp/agents-backend.yaml' };
  }
  const entry = config.backends[backendId] || {};
  const timeoutSeconds = timeoutSecondsOverride || config.timeoutSeconds || DEFAULT_TIMEOUT_SECONDS;
  const startedAt = Date.now();
  const result = await backend.run({
    prompt,
    command: entry.command || backend.defaultCommand,
    cwd: root,
    timeoutMs: timeoutSeconds * 1000,
  });
  return {
    ...result,
    backend: backendId,
    command: entry.command || backend.defaultCommand,
    duration_ms: Date.now() - startedAt,
    local_override: config.localOverride || null,
  };
}
