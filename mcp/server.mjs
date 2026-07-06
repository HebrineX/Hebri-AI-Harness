#!/usr/bin/env node
// Hebri-AI-Harness MCP daemon ("hebrinex").
// Envuelve los scripts PowerShell existentes del harness y expone el
// enforcement como tools MCP sobre stdio. No reimplementa politica: toda
// ejecucion pasa por scripts/command-gateway.ps1 y todo approval por
// scripts/hebrinex.ps1 approve. Las tools de lectura (session_contract,
// gate_check, memory_route, close_cycle_check) son read-only.

import { spawn } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(process.env.HEBRINEX_ROOT || join(HERE, '..'));
const IS_WINDOWS = process.platform === 'win32';
const DEFAULT_SPAWN_TIMEOUT_MS = 90_000;

// ---------------------------------------------------------------------------
// PowerShell bridge
// ---------------------------------------------------------------------------

let cachedPwsh = null;
function resolvePowerShell() {
  if (cachedPwsh) return cachedPwsh;
  if (process.env.HEBRINEX_PWSH) {
    cachedPwsh = process.env.HEBRINEX_PWSH;
    return cachedPwsh;
  }
  const candidates = IS_WINDOWS ? ['pwsh', 'powershell.exe'] : ['pwsh'];
  cachedPwsh = candidates[0];
  return cachedPwsh;
}

function killProcessTree(child) {
  try {
    if (IS_WINDOWS) {
      spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'], { stdio: 'ignore' });
    } else {
      child.kill('SIGKILL');
    }
  } catch {
    // best effort
  }
}

function runPowerShellFile(relativeScript, args, { timeoutMs = DEFAULT_SPAWN_TIMEOUT_MS } = {}) {
  const scriptPath = join(ROOT, relativeScript);
  if (!existsSync(scriptPath)) {
    return Promise.resolve({ exitCode: 127, stdout: '', stderr: `missing script: ${relativeScript}`, timedOut: false });
  }
  const exe = resolvePowerShell();
  const fullArgs = ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', scriptPath, ...args];
  return new Promise((resolvePromise) => {
    let child;
    try {
      child = spawn(exe, fullArgs, { cwd: ROOT, windowsHide: true });
    } catch (error) {
      resolvePromise({ exitCode: 127, stdout: '', stderr: `cannot spawn ${exe}: ${error.message}`, timedOut: false });
      return;
    }
    let stdout = '';
    let stderr = '';
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      killProcessTree(child);
      resolvePromise({ exitCode: 124, stdout, stderr: `${stderr}\n[hebrinex-mcp] timeout after ${timeoutMs}ms`.trim(), timedOut: true });
    }, timeoutMs);
    child.stdout.on('data', (chunk) => { stdout += chunk.toString('utf8'); });
    child.stderr.on('data', (chunk) => { stderr += chunk.toString('utf8'); });
    child.on('error', (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolvePromise({ exitCode: 127, stdout, stderr: `cannot spawn ${exe}: ${error.message}`, timedOut: false });
    });
    child.on('close', (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolvePromise({ exitCode: code == null ? 1 : code, stdout, stderr, timedOut: false });
    });
  });
}

function runGit(args, { timeoutMs = 30_000 } = {}) {
  return new Promise((resolvePromise) => {
    const child = spawn('git', ['-C', ROOT, ...args], { windowsHide: true });
    let stdout = '';
    let stderr = '';
    let settled = false;
    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      killProcessTree(child);
      resolvePromise({ exitCode: 124, stdout, stderr: 'git timed out', timedOut: true });
    }, timeoutMs);
    child.stdout.on('data', (chunk) => { stdout += chunk.toString('utf8'); });
    child.stderr.on('data', (chunk) => { stderr += chunk.toString('utf8'); });
    child.on('error', (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolvePromise({ exitCode: 127, stdout, stderr: error.message, timedOut: false });
    });
    child.on('close', (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolvePromise({ exitCode: code == null ? 1 : code, stdout, stderr, timedOut: false });
    });
  });
}

// ---------------------------------------------------------------------------
// YAML scalar helpers (espejo de Get-Scalar / Get-SectionScalar del harness;
// suficiente para los YAML planos del repo, sin dependencia externa)
// ---------------------------------------------------------------------------

function readText(relativePath) {
  const path = join(ROOT, relativePath);
  if (!existsSync(path)) return null;
  // Normaliza BOM y CRLF para que los helpers de escalares operen sobre LF.
  return readFileSync(path, 'utf8').replace(/^﻿/, '').replace(/\r\n/g, '\n');
}

function stripQuotes(value) {
  return value.trim().replace(/^"(.*)"$/s, '$1').replace(/^'(.*)'$/s, '$1');
}

function getScalar(text, key) {
  if (!text) return '';
  const re = new RegExp(`^\\s*${key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}:\\s*(.*)$`);
  for (const line of text.split('\n')) {
    const match = line.match(re);
    if (match) return stripQuotes(match[1]);
  }
  return '';
}

function getSectionScalar(text, section, key) {
  if (!text) return '';
  const sectionRe = new RegExp(`^${section.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}:\\s*$`);
  const keyRe = new RegExp(`^\\s+${key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}:\\s*(.*)$`);
  let inside = false;
  for (const line of text.split('\n')) {
    if (sectionRe.test(line)) { inside = true; continue; }
    if (inside && /^[A-Za-z0-9_.-]+:\s*/.test(line)) inside = false;
    if (inside) {
      const match = line.match(keyRe);
      if (match) return stripQuotes(match[1]);
    }
  }
  return '';
}

// Lista top-level: devuelve null si la clave no existe, [] si es "key: []",
// o los items "- ..." del bloque.
function getTopLevelList(text, key) {
  if (!text) return null;
  const lines = text.split('\n');
  const headRe = new RegExp(`^${key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}:\\s*(.*)$`);
  for (let i = 0; i < lines.length; i += 1) {
    const match = lines[i].match(headRe);
    if (!match) continue;
    const inline = match[1].trim();
    if (inline.startsWith('[')) {
      const body = inline.replace(/^\[/, '').replace(/\]\s*$/, '').trim();
      if (!body) return [];
      return body.split(',').map((item) => stripQuotes(item));
    }
    const items = [];
    for (let j = i + 1; j < lines.length; j += 1) {
      if (/^[A-Za-z0-9_.-]+:\s*/.test(lines[j])) break;
      const itemMatch = lines[j].match(/^\s*-\s*(.+?)\s*$/);
      if (itemMatch) items.push(stripQuotes(itemMatch[1]));
    }
    return items;
  }
  return null;
}

function getInlineBudget(budgetText, name) {
  if (!budgetText) return 0;
  const re = new RegExp(`^\\s*${name}:\\s*\\{[^}]*max_tokens(?:_before_user_logs)?:\\s*([0-9]+)`);
  for (const line of budgetText.split('\n')) {
    const match = line.match(re);
    if (match) return Number(match[1]);
  }
  return 0;
}

function estimateTokens(relativePaths) {
  let chars = 0;
  const loaded = [];
  for (const rel of relativePaths) {
    const path = join(ROOT, rel);
    if (existsSync(path)) {
      chars += statSync(path).size;
      loaded.push(rel);
    }
  }
  return { tokens: Math.ceil(chars / 4), loaded };
}

function parseKeyValueOutput(stdout) {
  const result = {};
  for (const line of stdout.split(/\r?\n/)) {
    const match = line.match(/^([a-z_0-9]+)=(.*)$/);
    if (match) result[match[1]] = match[2].trim();
  }
  return result;
}

// ---------------------------------------------------------------------------
// Tool result helpers
// ---------------------------------------------------------------------------

function ok(payload) {
  return { content: [{ type: 'text', text: JSON.stringify(payload, null, 2) }] };
}

function fail(payload) {
  return { isError: true, content: [{ type: 'text', text: JSON.stringify(payload, null, 2) }] };
}

// ---------------------------------------------------------------------------
// MCP server + tools
// ---------------------------------------------------------------------------

const server = new McpServer({
  name: 'hebrinex',
  version: '0.15.0',
});

// ---------------------------------------------------------------------------
// Identidad de rol de la sesion MCP.
//
// El rol vive en el estado del proceso del daemon: se asume via role_assume
// (validado contra orquestador/agents/agent-registry.yaml) y las tools con
// efecto (run_command, lock_acquire, lock_release) consultan
// scripts/agent-runtime.ps1 con ESE rol, no con uno declarado por el caller.
//
// Limite residual (documentado en orquestador/agents/README.md): el CLI
// directo sigue aceptando -RoleId autodeclarado; la garantia fuerte de
// identidad existe solo via MCP. Sin role_assume previo las tools con efecto
// funcionan sin check de rol (enforced=false), compatible con 0.13/0.14.
// ---------------------------------------------------------------------------

let assumedRole = '';

async function checkRoleCapability(capabilities) {
  if (!assumedRole) return { enforced: false, allowed: true, role: '' };
  const attempts = [];
  for (const capability of capabilities) {
    const run = await runPowerShellFile('scripts/agent-runtime.ps1', [
      '-Root', ROOT, '-RoleId', assumedRole, '-Capability', capability, '-Json',
    ]);
    let decision = null;
    try { decision = JSON.parse(run.stdout); } catch { decision = null; }
    attempts.push({ capability, decision: decision?.decision ?? 'error', reason: decision?.reason ?? 'agent_runtime_output_not_json' });
    if (run.exitCode === 0 && decision?.decision === 'allow') {
      return { enforced: true, allowed: true, role: assumedRole, capability };
    }
  }
  return { enforced: true, allowed: false, role: assumedRole, attempts };
}

function roleBlocked(toolName, roleCheck) {
  return fail({
    status: 'blocked',
    reason: 'role_capability_blocked',
    tool: toolName,
    role: roleCheck.role,
    attempts: roleCheck.attempts,
    next_step: 'El rol asumido via role_assume no tiene la capability requerida; asumir un rol con permiso o pedir SI al operador.',
  });
}

// 1. run_command — unica via de ejecucion. Todo pasa por el command gateway.
server.registerTool('run_command', {
  title: 'Hebrinex command gateway (Apply)',
  description: [
    'Ejecuta un comando via scripts/command-gateway.ps1 -Apply. Es la UNICA via',
    'de ejecucion del harness: solo corre comandos read-only allowlisteados y',
    'valida approval_id contra el approval store. Si el gateway decide block,',
    'la tool falla con el reason y el preflight generado.',
  ].join(' '),
  inputSchema: {
    command_text: z.string().min(1).describe('Comando exacto a ejecutar (texto literal).'),
    purpose: z.string().optional().describe('Proposito declarado del comando.'),
    approval_id: z.string().optional().describe('Approval ID (APR-...) emitido por preflight_approve, si la accion lo requiere.'),
    risk_class: z.string().optional().describe('Risk class declarada; si no coincide con la detectada, el gateway bloquea.'),
    timeout_seconds: z.number().int().min(1).max(120).optional().describe('Timeout del comando en segundos (1-120, default 30).'),
  },
}, async ({ command_text, purpose, approval_id, risk_class, timeout_seconds }) => {
  // Con rol asumido, ejecutar comandos requiere una capability de comando local:
  // run_local_validation (roles que implementan) o run_readonly_audit (roles
  // read-only). Cualquiera de las dos habilita; sin rol asumido no hay check.
  const roleCheck = await checkRoleCapability(['run_local_validation', 'run_readonly_audit']);
  if (!roleCheck.allowed) return roleBlocked('run_command', roleCheck);
  const args = ['-Root', ROOT, '-Apply', '-Json', '-CommandText', command_text];
  if (purpose) args.push('-Purpose', purpose);
  if (approval_id) args.push('-ApprovalId', approval_id);
  if (risk_class) args.push('-RiskClass', risk_class);
  if (timeout_seconds) args.push('-TimeoutSeconds', String(timeout_seconds));
  const run = await runPowerShellFile('scripts/command-gateway.ps1', args);
  if (run.timedOut) {
    return fail({ decision: 'error', reason: 'gateway_timeout', stderr: run.stderr });
  }
  let result;
  try {
    result = JSON.parse(run.stdout);
  } catch {
    return fail({
      decision: 'error',
      reason: 'gateway_output_not_json',
      exit_code: run.exitCode,
      stdout: run.stdout.slice(0, 4000),
      stderr: run.stderr.slice(0, 4000),
    });
  }
  if (result.decision !== 'allow') {
    return fail({
      decision: result.decision,
      reason: result.reason,
      risk_class: result.risk_class,
      approval_status: result.approval_status,
      approval_reason: result.approval_reason,
      generated_preflight: result.generated_preflight,
      next_step: result.next_step,
    });
  }
  return ok({
    decision: result.decision,
    reason: result.reason,
    risk_class: result.risk_class,
    approval_status: result.approval_status,
    executes: result.executes,
    execution: result.execution,
    next_step: result.next_step,
    assumed_role: assumedRole || null,
    role_enforced: roleCheck.enforced,
  });
});

// 2a. preflight_approve — materializa el SI del operador como envelope.
server.registerTool('preflight_approve', {
  title: 'Hebrinex approval envelope (Apply)',
  description: [
    'Crea un approval envelope via `hebrinex approve -Apply` para la accion',
    'exacta indicada y devuelve approval_id + expiracion. El envelope solo es',
    'valido para ese texto de comando exacto (hash SHA-256) y hasta expirar.',
    'Solo usar despues de que el operador humano dio el SI.',
  ].join(' '),
  inputSchema: {
    command_text: z.string().min(1).describe('Accion exacta aprobada por el operador (texto literal).'),
    purpose: z.string().optional().describe('Proposito de la accion aprobada.'),
    ttl_minutes: z.number().int().min(1).max(1440).optional().describe('Vigencia del approval en minutos (1-1440, default 60).'),
  },
}, async ({ command_text, purpose, ttl_minutes }) => {
  const args = ['approve', '-Root', ROOT, '-Apply', '-CommandText', command_text];
  if (purpose) args.push('-Purpose', purpose);
  if (ttl_minutes) args.push('-TtlMinutes', String(ttl_minutes));
  const run = await runPowerShellFile('scripts/hebrinex.ps1', args);
  if (run.exitCode !== 0 || run.timedOut) {
    return fail({ status: 'error', reason: 'approve_failed', exit_code: run.exitCode, stderr: run.stderr.slice(0, 4000), stdout: run.stdout.slice(0, 4000) });
  }
  const parsed = parseKeyValueOutput(run.stdout);
  if (!parsed.approval_id) {
    return fail({ status: 'error', reason: 'approve_output_missing_approval_id', stdout: run.stdout.slice(0, 4000) });
  }
  return ok({
    status: 'recorded',
    approval_id: parsed.approval_id,
    expires_at: parsed.expires_at || '',
    approval_path: parsed.approval_path || '',
    command_sha256: parsed.command_sha256 || '',
    usage: 'Pasar approval_id a run_command junto con el mismo command_text exacto.',
  });
});

// 2b. approval_check — valida un approval id contra el almacen sin ejecutar.
server.registerTool('approval_check', {
  title: 'Hebrinex approval check (read-only)',
  description: [
    'Valida un approval_id contra el approval store del harness (existencia,',
    'estado approved, expiracion y hash exacto del comando) reutilizando el',
    'command gateway en modo CheckOnly. No ejecuta nada.',
  ].join(' '),
  inputSchema: {
    approval_id: z.string().min(1).describe('Approval ID (APR-...) a validar.'),
    command_text: z.string().min(1).describe('Comando exacto contra el que se valida el envelope.'),
  },
}, async ({ approval_id, command_text }) => {
  const args = ['-Root', ROOT, '-CheckOnly', '-Json', '-CommandText', command_text, '-ApprovalId', approval_id];
  const run = await runPowerShellFile('scripts/command-gateway.ps1', args);
  let result;
  try {
    result = JSON.parse(run.stdout);
  } catch {
    return fail({ status: 'error', reason: 'gateway_output_not_json', exit_code: run.exitCode, stderr: run.stderr.slice(0, 4000) });
  }
  const valid = result.approval_status === 'valid';
  const payload = {
    approval_id,
    valid,
    approval_status: result.approval_status,
    approval_reason: result.approval_reason,
    gateway_decision: result.decision,
    gateway_reason: result.reason,
  };
  return valid ? ok(payload) : fail(payload);
});

// 3. session_contract — arma el contrato de sesion dentro del presupuesto.
server.registerTool('session_contract', {
  title: 'Hebrinex session contract (read-only)',
  description: [
    'Lee PROJECT_BINDING.yaml + state.yaml + registry.yaml + context-budget.yaml',
    'y devuelve el contrato de sesion ya armado (formato de',
    'orquestador/method/session-contract.md) junto con el uso de presupuesto',
    'del perfil leader_light.',
  ].join(' '),
  inputSchema: {},
}, async () => {
  const binding = readText('PROJECT_BINDING.yaml');
  const state = readText('orquestador/sdd/progress/state.yaml');
  const registry = readText('orquestador/sdd/progress/registry.yaml');
  const budget = readText('orquestador/context-budget.yaml');
  const missing = [];
  if (!binding) missing.push('PROJECT_BINDING.yaml');
  if (!state) missing.push('orquestador/sdd/progress/state.yaml');
  if (!registry) missing.push('orquestador/sdd/progress/registry.yaml');
  if (!budget) missing.push('orquestador/context-budget.yaml');
  if (missing.length > 0) {
    return fail({ status: 'error', reason: 'missing_kernel_files', missing });
  }

  const bindingMode = getScalar(binding, 'binding_mode');
  const harnessVersion = getScalar(binding, 'harness_version');
  const projectRoot = getScalar(binding, 'project_root') || (bindingMode === 'source_template' ? ROOT : '');
  const mode = getScalar(state, 'mode');
  const contractStatus = getSectionScalar(state, 'session_contract', 'status');
  const leaderVisible = getSectionScalar(state, 'session_contract', 'leader_visible');
  const cycleId = getSectionScalar(state, 'active_cycle', 'cycle_id');
  const phaseId = getSectionScalar(state, 'active_cycle', 'phase_id');
  const sliceId = getSectionScalar(state, 'active_cycle', 'slice_id');
  const cycleStatus = getSectionScalar(state, 'active_cycle', 'status');
  const activeApprovalId = getSectionScalar(state, 'approvals', 'active_approval_id');
  const openAgents = getTopLevelList(state, 'open_agents') || [];
  const openLocks = getTopLevelList(state, 'open_locks') || [];
  const defaultRoute = getSectionScalar(budget, 'default_policy', 'default_route') || 'reentry_light';

  // Mismo file-set que `hebrinex budget` usa para el perfil leader_light.
  const leaderLightFiles = [
    'PROJECT_BINDING.yaml',
    'orquestador/memory/local/session-pin.md',
    'orquestador/memory/memory-registry.yaml',
    'orquestador/memory/memory-routing.yaml',
    'orquestador/context-budget.yaml',
    'orquestador/sdd/progress/state.yaml',
    'orquestador/sdd/progress/registry.yaml',
    'orquestador/method/session-contract.md',
  ];
  const maxTokens = getInlineBudget(budget, 'leader_light');
  const { tokens: usedTokens, loaded } = estimateTokens(leaderLightFiles);
  const hardLimit = maxTokens * 2;
  let budgetStatus = 'ok';
  if (maxTokens > 0 && usedTokens > hardLimit) budgetStatus = 'block';
  else if (maxTokens > 0 && usedTokens > maxTokens) budgetStatus = 'warn';

  const contractLines = [
    'Contrato de sesion:',
    `- Harness path: ${ROOT}`,
    `- Project root: ${projectRoot || '(sin definir)'}`,
    `- Binding/version: ${bindingMode} / ${harnessVersion}`,
    `- Memory route/budget: ${defaultRoute} / leader_light ${usedTokens}/${maxTokens} (${budgetStatus})`,
    `- Modo: ${mode || 'automatico'}`,
    '- Rol del chat: interprete',
    `- Leader visible: ${leaderVisible || 'false'}`,
    `- Subagentes activos: ${openAgents.length}/4`,
    `- Fase/Slice activo: ${cycleId || '(ninguno)'} / ${phaseId || '-'} / ${sliceId || '-'}`,
    `- Estado SDD: session_contract=${contractStatus || 'pending'}, active_cycle=${cycleStatus || 'pending'}, open_locks=${openLocks.length}`,
    '- Proxima accion: pendiente de operador',
    `- Aprobacion requerida: SI antes de efectos${activeApprovalId ? ` (approval activo: ${activeApprovalId})` : ''}`,
  ];

  const result = {
    contract_text: contractLines.join('\n'),
    binding_mode: bindingMode,
    harness_version: harnessVersion,
    project_root: projectRoot,
    mode: mode || 'automatico',
    session_contract_status: contractStatus || 'pending',
    leader_visible: leaderVisible === 'true',
    active_cycle: { cycle_id: cycleId, phase_id: phaseId, slice_id: sliceId, status: cycleStatus || 'pending' },
    open_agents: openAgents.length,
    open_locks: openLocks.length,
    active_approval_id: activeApprovalId,
    context_budget: {
      profile: 'leader_light',
      estimated_tokens: usedTokens,
      max_tokens: maxTokens,
      hard_limit: hardLimit,
      status: budgetStatus,
      files_loaded: loaded,
    },
  };
  return budgetStatus === 'block' ? fail({ ...result, reason: 'context_budget_hard_limit_exceeded' }) : ok(result);
});

// 4. gate_check — clasifica gates condicionales segun scope tocado (read-only).
const GATE_DOMAINS = [
  {
    id: 'G5B_release_reconstruction_complete',
    kind: 'required',
    description: 'Reconstruccion release (CHANGELOG, version, manifest, README).',
    patterns: [/^CHANGELOG\.md$/, /^HARNESS_VERSION$/, /^README\.md$/, /^orquestador\/harness-manifest\.txt$/, /^scripts\/validate-release\.ps1$/],
  },
  {
    id: 'G5C_deploy_migration_complete',
    kind: 'conditional',
    description: 'Deploy/migracion (rutas, contratos y validadores de migracion).',
    patterns: [/^orquestador\/migration\//, /^scripts\/(migrate-harness|validate-migration)\.ps1$/],
  },
  {
    id: 'G5D_reference_drift_complete',
    kind: 'conditional',
    description: 'Drift de referencias (docs operativas, adapters, prompts, metodos).',
    patterns: [/^AGENTS\.md$/, /^README\.md$/, /^orquestador\/adapters\//, /^orquestador\/method\//, /^prompts\//, /^orquestador\/instruction-builder\//],
  },
  {
    id: 'G5E_ci_pipeline_history_complete',
    kind: 'conditional',
    description: 'Pipeline CI (workflows y validadores que corre CI).',
    patterns: [/^\.github\/workflows\//, /^init\.sh$/],
  },
  {
    id: 'G5F_backlog_classification_complete',
    kind: 'conditional',
    description: 'Backlog (bloqueos y future-p1).',
    patterns: [/^orquestador\/sdd\/progress\/(blocked|future-p1)\.md$/],
  },
  {
    id: 'G5G_audit_report_contract_complete',
    kind: 'conditional',
    description: 'Contrato de reporte de auditoria.',
    patterns: [/^scripts\/audit-harness\.ps1$/, /^orquestador\/method\/final-report-evidence-policy\.md$/],
  },
  {
    id: 'G5H_final_report_crosslink_complete',
    kind: 'conditional',
    description: 'Crosslink de reporte final (registry, ciclos, reportes).',
    patterns: [/^orquestador\/sdd\/progress\/(registry\.(yaml|md)|cycles\/)/],
  },
  {
    id: 'G5I_memory_consistency_complete',
    kind: 'required',
    description: 'Consistencia de memoria (capas local/daily/cycle/project).',
    patterns: [/^orquestador\/memory\//],
  },
];

server.registerTool('gate_check', {
  title: 'Hebrinex gate check (read-only)',
  description: [
    'Mira git status/diff (solo lectura) y clasifica que gates G5B..G5I de',
    'orquestador/gate-registry.yaml aplican al scope tocado en el working tree.',
  ].join(' '),
  inputSchema: {},
}, async () => {
  const status = await runGit(['status', '--porcelain']);
  if (status.exitCode !== 0) {
    return fail({ status: 'error', reason: 'git_status_failed', stderr: status.stderr.slice(0, 2000) });
  }
  const staged = await runGit(['diff', '--name-only', '--cached']);
  const files = new Set();
  for (const line of status.stdout.split('\n')) {
    if (!line.trim()) continue;
    // porcelain: XY <path> (o "XY <old> -> <new>" para renames)
    const rawPath = line.slice(3).trim();
    const renamed = rawPath.split(' -> ');
    files.add(renamed[renamed.length - 1].replace(/^"|"$/g, ''));
  }
  for (const line of staged.stdout.split('\n')) {
    if (line.trim()) files.add(line.trim());
  }
  const touched = [...files].sort();
  const gates = GATE_DOMAINS.map((gate) => {
    const matched = touched.filter((file) => gate.patterns.some((re) => re.test(file)));
    return {
      id: gate.id,
      kind: gate.kind,
      description: gate.description,
      applies: gate.kind === 'required' ? true : matched.length > 0,
      triggered_by_scope: matched.length > 0,
      matched_files: matched.slice(0, 50),
    };
  });
  return ok({
    touched_files_count: touched.length,
    touched_files: touched.slice(0, 200),
    gates,
    notes: [
      'G5B y G5I son required en gate-registry.yaml: aplican siempre; triggered_by_scope indica si el scope actual los toca directamente.',
      'Los gates condicionales (G5C..G5H) solo se exigen cuando applies=true.',
    ],
  });
});

// 5. memory_route — decide el entrypoint segun estado real de la sesion.
server.registerTool('memory_route', {
  title: 'Hebrinex memory route (read-only)',
  description: [
    'Decide el entrypoint de memoria (first_message | reentry_light |',
    'debug_log_intake | compactation_recovery) segun el estado real de',
    'state.yaml y los archivos de memoria, con hints opcionales de la sesion.',
  ].join(' '),
  inputSchema: {
    resumed_from_summary: z.boolean().optional().describe('true si el hilo fue compactado o retomado desde un resumen.'),
    has_user_logs: z.boolean().optional().describe('true si el usuario pego logs de error/build/test para procesar.'),
  },
}, async ({ resumed_from_summary, has_user_logs }) => {
  const state = readText('orquestador/sdd/progress/state.yaml');
  const routing = readText('orquestador/memory/memory-routing.yaml');
  if (!state || !routing) {
    return fail({ status: 'error', reason: 'missing_state_or_routing_files' });
  }
  const contractStatus = getSectionScalar(state, 'session_contract', 'status');
  const cycleStatus = getSectionScalar(state, 'active_cycle', 'status');
  const progressDir = join(ROOT, 'orquestador/sdd/progress');
  const handoffs = existsSync(progressDir)
    ? readdirSync(progressDir).filter((name) => /^HANDOFF-.*\.md$/i.test(name))
    : [];

  let route = 'reentry_light';
  let reason = 'sesion con contrato o ciclo previo: reentrada liviana por defecto.';
  if (resumed_from_summary === true) {
    route = 'compactation_recovery';
    reason = 'hint de sesion: hilo compactado o retomado desde resumen.';
  } else if (handoffs.length > 0) {
    route = 'compactation_recovery';
    reason = `handoff de continuidad presente en progress/ (${handoffs.join(', ')}): tratar como recuperacion.`;
  } else if (has_user_logs === true) {
    route = 'debug_log_intake';
    reason = 'hint de sesion: el usuario pego logs para procesar.';
  } else if ((contractStatus === '' || contractStatus === 'pending') && (cycleStatus === '' || cycleStatus === 'pending')) {
    route = 'first_message';
    reason = 'session_contract y active_cycle en pending: sesion nueva.';
  }

  const routeLine = routing.split('\n').find((line) => line.trim().startsWith(`${route}:`)) || '';
  const entrypointMatch = routeLine.match(/entrypoint:\s*([^,}]+)/);
  const layersMatch = routeLine.match(/layers:\s*\[([^\]]*)\]/);
  return ok({
    route,
    reason,
    entrypoint: entrypointMatch ? entrypointMatch[1].trim() : '',
    layers: layersMatch ? layersMatch[1].split(',').map((layer) => layer.trim()) : [],
    signals: {
      session_contract_status: contractStatus || 'pending',
      active_cycle_status: cycleStatus || 'pending',
      handoff_files: handoffs,
      resumed_from_summary: resumed_from_summary === true,
      has_user_logs: has_user_logs === true,
    },
  });
});

// 6. close_cycle_check — verifica el memory-closure-checklist antes de `done`.
server.registerTool('close_cycle_check', {
  title: 'Hebrinex close cycle check (read-only)',
  description: [
    'Verifica las precondiciones del memory-closure-checklist (existencia de',
    'archivos de evidencia, locks/agentes abiertos, reporte final) antes de',
    'permitir declarar `done`. Devuelve pass=false con gaps si falta algo.',
  ].join(' '),
  inputSchema: {},
}, async () => {
  const gaps = [];
  const evidence = {};

  const state = readText('orquestador/sdd/progress/state.yaml');
  if (!state) {
    return fail({ pass: false, gaps: ['missing: orquestador/sdd/progress/state.yaml'] });
  }
  const openLocks = getTopLevelList(state, 'open_locks');
  const openAgents = getTopLevelList(state, 'open_agents');
  evidence.open_locks = openLocks === null ? 'missing_key' : openLocks.length;
  evidence.open_agents = openAgents === null ? 'missing_key' : openAgents.length;
  if (openLocks === null || openLocks.length > 0) gaps.push('cycle: open_locks debe estar vacio o justificado como blocked.');
  if (openAgents === null || openAgents.length > 0) gaps.push('cycle: open_agents debe estar vacio o justificado como blocked.');

  const lastFinalReport = getScalar(state, 'last_final_report');
  evidence.last_final_report = lastFinalReport || '(vacio)';
  if (!lastFinalReport) {
    gaps.push('cycle: last_final_report vacio en state.yaml (falta reporte final enlazado).');
  } else if (!existsSync(join(ROOT, lastFinalReport))) {
    gaps.push(`cycle: last_final_report apunta a archivo inexistente: ${lastFinalReport}`);
  }

  const requiredFiles = [
    ['local', 'orquestador/memory/local/active-contract.md'],
    ['local', 'orquestador/memory/local/current-focus.md'],
    ['local', 'orquestador/memory/local/session-pin.md'],
    ['cycle', 'orquestador/sdd/progress/registry.yaml'],
    ['checklist', 'orquestador/sdd/progress/templates/memory-closure-checklist.md'],
  ];
  for (const [layer, rel] of requiredFiles) {
    const present = existsSync(join(ROOT, rel));
    evidence[rel] = present;
    if (!present) gaps.push(`${layer}: falta ${rel}`);
  }

  // Handoffs de continuidad abiertos bloquean el cierre (hard lock 5).
  const progressDir = join(ROOT, 'orquestador/sdd/progress');
  const handoffs = existsSync(progressDir)
    ? readdirSync(progressDir).filter((name) => /^HANDOFF-.*\.md$/i.test(name))
    : [];
  evidence.open_handoffs = handoffs;
  if (handoffs.length > 0) {
    gaps.push(`cierre: handoffs de continuidad abiertos (${handoffs.join(', ')}); resolver o borrar antes de done.`);
  }

  const verificationStatus = getSectionScalar(state, 'verification', 'status');
  evidence.verification_status = verificationStatus || 'not_defined';
  if (verificationStatus !== 'passed' && verificationStatus !== 'not_applicable') {
    gaps.push(`cycle: verification.status=${verificationStatus || 'not_defined'} (se espera passed o not_applicable).`);
  }

  const pass = gaps.length === 0;
  const payload = {
    pass,
    gaps,
    evidence,
    checklist_source: 'orquestador/sdd/progress/templates/memory-closure-checklist.md',
    rule: 'No declarar done si hay gaps: local/daily/cycle/project deben evaluarse antes de cerrar.',
  };
  return pass ? ok(payload) : fail(payload);
});

// 7. session_usage — consumo real de tokens/costo desde los transcripts de
// Claude Code de este proyecto. Read-only; precios en mcp/model-pricing.yaml.

function parsePricingModels(text) {
  const models = {};
  let inside = false;
  for (const line of text.split('\n')) {
    if (/^models:\s*$/.test(line)) { inside = true; continue; }
    if (inside && /^[A-Za-z0-9_.-]+:/.test(line)) inside = false;
    if (!inside) continue;
    const match = line.match(/^\s+([A-Za-z0-9._-]+):\s*\{([^}]*)\}/);
    if (!match) continue;
    const fields = {};
    for (const part of match[2].split(',')) {
      const idx = part.indexOf(':');
      if (idx === -1) continue;
      const key = part.slice(0, idx).trim();
      const value = Number(part.slice(idx + 1).trim());
      if (key && Number.isFinite(value)) fields[key] = value;
    }
    models[match[1]] = fields;
  }
  return models;
}

// Prefijo mas largo: "claude-haiku-4-5-20251001" matchea "claude-haiku-4-5".
function findPricing(models, modelId) {
  if (!modelId) return null;
  if (models[modelId]) return models[modelId];
  let best = null;
  for (const key of Object.keys(models)) {
    if (modelId.startsWith(key) && (!best || key.length > best.length)) best = key;
  }
  return best ? models[best] : null;
}

function claudeProjectsDir() {
  // Claude Code deriva el nombre del directorio del proyecto reemplazando todo
  // caracter no alfanumerico del path por '-'.
  return join(homedir(), '.claude', 'projects', ROOT.replace(/[^A-Za-z0-9]/g, '-'));
}

server.registerTool('session_usage', {
  title: 'Hebrinex session usage (read-only)',
  description: [
    'Parsea los transcripts JSONL de Claude Code de este proyecto',
    '(~/.claude/projects/<proyecto>/*.jsonl) y reporta, para la sesion mas',
    'reciente o un session_id dado: tokens in/out/cache totales, turnos y costo',
    'estimado en USD segun mcp/model-pricing.yaml (tabla editable). Read-only;',
    'si no hay transcripts falla con error claro, no inventa datos.',
  ].join(' '),
  inputSchema: {
    session_id: z.string().optional().describe('Session id (uuid del .jsonl); default: la sesion mas reciente por mtime.'),
  },
}, async ({ session_id }) => {
  const projectsDir = claudeProjectsDir();
  if (!existsSync(projectsDir)) {
    return fail({ status: 'error', reason: 'transcripts_dir_not_found', transcripts_dir: projectsDir });
  }
  let transcriptPath;
  if (session_id) {
    if (!/^[A-Za-z0-9-]+$/.test(session_id)) {
      return fail({ status: 'error', reason: 'invalid_session_id', session_id });
    }
    transcriptPath = join(projectsDir, `${session_id}.jsonl`);
    if (!existsSync(transcriptPath)) {
      return fail({ status: 'error', reason: 'transcript_not_found', transcript: transcriptPath });
    }
  } else {
    const candidates = readdirSync(projectsDir)
      .filter((name) => name.endsWith('.jsonl'))
      .map((name) => ({ name, mtime: statSync(join(projectsDir, name)).mtimeMs }))
      .sort((a, b) => b.mtime - a.mtime);
    if (candidates.length === 0) {
      return fail({ status: 'error', reason: 'no_transcripts_found', transcripts_dir: projectsDir });
    }
    transcriptPath = join(projectsDir, candidates[0].name);
  }

  const pricingText = readText('mcp/model-pricing.yaml');
  if (!pricingText) {
    return fail({ status: 'error', reason: 'pricing_file_missing', expected: 'mcp/model-pricing.yaml' });
  }
  const pricingModels = parsePricingModels(pricingText);

  const totals = { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 };
  const byModel = {};
  let assistantTurns = 0;
  let userTurns = 0;
  let parseErrors = 0;
  let firstTimestamp = '';
  let lastTimestamp = '';
  for (const line of readFileSync(transcriptPath, 'utf8').split(/\r?\n/)) {
    if (!line.trim()) continue;
    let entry;
    try { entry = JSON.parse(line); } catch { parseErrors += 1; continue; }
    if (entry.timestamp) {
      if (!firstTimestamp) firstTimestamp = entry.timestamp;
      lastTimestamp = entry.timestamp;
    }
    if (entry.type === 'user') { userTurns += 1; continue; }
    if (entry.type !== 'assistant') continue;
    const usage = entry.message?.usage;
    if (!usage) continue;
    assistantTurns += 1;
    const model = entry.message?.model || 'unknown';
    if (!byModel[model]) {
      byModel[model] = {
        input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0,
        cache_creation_input_tokens: 0, cache_creation_5m_tokens: 0, cache_creation_1h_tokens: 0,
        messages: 0,
      };
    }
    const bucket = byModel[model];
    bucket.messages += 1;
    for (const key of ['input_tokens', 'output_tokens', 'cache_read_input_tokens', 'cache_creation_input_tokens']) {
      const value = Number(usage[key]) || 0;
      bucket[key] += value;
      totals[key] += value;
    }
    const creation = usage.cache_creation || {};
    bucket.cache_creation_5m_tokens += Number(creation.ephemeral_5m_input_tokens) || 0;
    bucket.cache_creation_1h_tokens += Number(creation.ephemeral_1h_input_tokens) || 0;
  }

  if (assistantTurns === 0) {
    return fail({ status: 'error', reason: 'no_assistant_usage_in_transcript', transcript: transcriptPath });
  }

  let totalCost = 0;
  let costComplete = true;
  const models = {};
  const unpricedModels = [];
  for (const [model, bucket] of Object.entries(byModel)) {
    const pricing = findPricing(pricingModels, model);
    const bucketTokens = bucket.input_tokens + bucket.output_tokens
      + bucket.cache_read_input_tokens + bucket.cache_creation_input_tokens;
    let cost = null;
    if (bucketTokens === 0) {
      // Mensajes sinteticos/sin usage no aportan costo ni invalidan el total.
      cost = 0;
    } else if (pricing) {
      // Si no hay desglose 5m/1h se cobra la creacion entera a tarifa 5m.
      const write5m = bucket.cache_creation_5m_tokens || (bucket.cache_creation_1h_tokens ? 0 : bucket.cache_creation_input_tokens);
      const write1h = bucket.cache_creation_1h_tokens;
      cost = (bucket.input_tokens * (pricing.input || 0)
        + bucket.output_tokens * (pricing.output || 0)
        + bucket.cache_read_input_tokens * (pricing.cache_read || 0)
        + write5m * (pricing.cache_write_5m || 0)
        + write1h * (pricing.cache_write_1h || 0)) / 1_000_000;
      totalCost += cost;
    } else {
      costComplete = false;
      unpricedModels.push(model);
    }
    models[model] = { ...bucket, estimated_cost_usd: cost === null ? null : Number(cost.toFixed(4)) };
  }

  return ok({
    session_id: session_id || transcriptPath.split(/[\\/]/).pop().replace(/\.jsonl$/, ''),
    transcript: transcriptPath,
    first_timestamp: firstTimestamp,
    last_timestamp: lastTimestamp,
    turns: { assistant_messages: assistantTurns, user_messages: userTurns },
    totals,
    models,
    estimated_cost_usd: Number(totalCost.toFixed(4)),
    cost_complete: costComplete,
    unpriced_models: unpricedModels,
    pricing_source: 'mcp/model-pricing.yaml',
    parse_errors: parseErrors,
    notes: 'Costo estimado con precios de lista; cache_creation sin desglose 5m/1h se cobra a tarifa 5m.',
  });
});

// 8. role_assume — fija el rol de la sesion MCP en el estado del daemon.
server.registerTool('role_assume', {
  title: 'Hebrinex role assume (daemon state)',
  description: [
    'Valida role_id contra orquestador/agents/agent-registry.yaml y lo guarda',
    'como rol de la sesion en el estado del proceso del daemon. A partir de ahi',
    'las tools con efecto (run_command, lock_acquire, lock_release) consultan',
    'scripts/agent-runtime.ps1 con ESE rol; el caller no puede declarar otro.',
    'Limite residual documentado: el CLI directo sigue aceptando -RoleId',
    'autodeclarado; la garantia fuerte existe solo via MCP.',
  ].join(' '),
  inputSchema: {
    role_id: z.string().min(1).describe('Rol del agent-registry (leader, implementer, reviewer, auditor, reporter, spec-author, worker).'),
  },
}, async ({ role_id }) => {
  const registry = readText('orquestador/agents/agent-registry.yaml');
  if (!registry) {
    return fail({ status: 'error', reason: 'missing_agent_registry' });
  }
  const roleRe = new RegExp(`^\\s*-\\s*id:\\s*${role_id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*$`, 'm');
  if (!roleRe.test(registry)) {
    return fail({ status: 'error', reason: 'unknown_role', role_id, registry: 'orquestador/agents/agent-registry.yaml' });
  }
  const previousRole = assumedRole;
  assumedRole = role_id;
  return ok({
    status: 'assumed',
    role_id,
    previous_role: previousRole || null,
    contract_ref: `orquestador/agents/role-contracts/${role_id}.yaml`,
    scope: 'proceso del daemon MCP (esta sesion); las tools con efecto usan este rol via agent-runtime.ps1',
  });
});

// 9a. lock_acquire — envuelve `hebrinex lock -Acquire` con el rol del daemon.
server.registerTool('lock_acquire', {
  title: 'Hebrinex lock acquire (Apply)',
  description: [
    'Adquiere un lock exclusivo via `hebrinex lock -Acquire` sobre los paths',
    'indicados (L-*.lock.md en orquestador/sdd/progress/locks/ con owner y TTL).',
    'Solapamiento con un lock activo no vencido falla con lock_conflict. Con rol',
    'asumido via role_assume exige la capability edit_approved_write_set.',
  ].join(' '),
  inputSchema: {
    paths: z.array(z.string().min(1)).min(1).describe('Paths relativos a lockear (exclusivo).'),
    owner: z.string().optional().describe('Owner declarado; default: el rol asumido o "mcp-daemon".'),
    ttl_minutes: z.number().int().min(1).max(1440).optional().describe('TTL del lock en minutos (default 120).'),
    reason: z.string().optional().describe('Motivo del lock.'),
  },
}, async ({ paths, owner, ttl_minutes, reason }) => {
  const roleCheck = await checkRoleCapability(['edit_approved_write_set']);
  if (!roleCheck.allowed) return roleBlocked('lock_acquire', roleCheck);
  const effectiveOwner = owner || assumedRole || 'mcp-daemon';
  const args = ['lock', '-Root', ROOT, '-Acquire', '-Paths', paths.join(','), '-Owner', effectiveOwner];
  if (ttl_minutes) args.push('-TtlMinutes', String(ttl_minutes));
  if (reason) args.push('-Reason', reason);
  const run = await runPowerShellFile('scripts/hebrinex.ps1', args);
  if (run.exitCode !== 0 || run.timedOut) {
    const conflict = (run.stderr || '').match(/lock_conflict[^\n]*/);
    return fail({
      status: 'error',
      reason: conflict ? conflict[0] : 'lock_acquire_failed',
      exit_code: run.exitCode,
      stderr: run.stderr.slice(0, 2000),
    });
  }
  const parsed = parseKeyValueOutput(run.stdout);
  if (!parsed.lock_id) {
    return fail({ status: 'error', reason: 'lock_output_missing_lock_id', stdout: run.stdout.slice(0, 2000) });
  }
  return ok({
    status: 'acquired',
    lock_id: parsed.lock_id,
    lock_path: parsed.lock_path || '',
    owner: parsed.owner || effectiveOwner,
    expires_at: parsed.expires_at || '',
    paths,
    assumed_role: assumedRole || null,
    role_enforced: roleCheck.enforced,
  });
});

// 9b. lock_release — envuelve `hebrinex lock -Release`.
server.registerTool('lock_release', {
  title: 'Hebrinex lock release (Apply)',
  description: [
    'Libera un lock via `hebrinex lock -Release -LockId L-...` (marca',
    'status: released; el archivo queda como evidencia). Con rol asumido via',
    'role_assume exige la capability edit_approved_write_set.',
  ].join(' '),
  inputSchema: {
    lock_id: z.string().min(1).describe('Lock ID (L-...) a liberar.'),
  },
}, async ({ lock_id }) => {
  const roleCheck = await checkRoleCapability(['edit_approved_write_set']);
  if (!roleCheck.allowed) return roleBlocked('lock_release', roleCheck);
  const run = await runPowerShellFile('scripts/hebrinex.ps1', ['lock', '-Root', ROOT, '-Release', '-LockId', lock_id]);
  if (run.exitCode !== 0 || run.timedOut) {
    const notFound = /lock_not_found/.test(run.stderr || '');
    return fail({
      status: 'error',
      reason: notFound ? 'lock_not_found' : 'lock_release_failed',
      exit_code: run.exitCode,
      stderr: run.stderr.slice(0, 2000),
    });
  }
  const parsed = parseKeyValueOutput(run.stdout);
  return ok({
    status: 'released',
    lock_id,
    lock_path: parsed.lock_path || '',
    previous_status: parsed.previous_status || '',
    assumed_role: assumedRole || null,
    role_enforced: roleCheck.enforced,
  });
});

// ---------------------------------------------------------------------------

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(`[hebrinex-mcp] listo. root=${ROOT}`);
