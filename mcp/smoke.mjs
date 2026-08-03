#!/usr/bin/env node
// Smoke test del daemon MCP hebrinex. Levanta server.mjs por stdio como un
// cliente MCP real, valida que las 13 tools esten registradas y ejercita las
// tools read-only, run_command (allow + block), el ciclo de locks
// (acquire -> conflicto -> release), la identidad de rol (role_assume +
// capability block) y los errores claros de agent_audit/agent_review sin
// backend. Exit 0 = OK, exit 1 = fallo (con detalle por stderr).

import { rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const HERE = dirname(fileURLToPath(import.meta.url));
const failures = [];

function check(condition, label) {
  if (condition) {
    console.error(`ok: ${label}`);
  } else {
    failures.push(label);
    console.error(`FAIL: ${label}`);
  }
}

function parsePayload(result) {
  try {
    return JSON.parse(result.content?.[0]?.text ?? 'null');
  } catch {
    return null;
  }
}

const transport = new StdioClientTransport({
  command: process.execPath,
  args: [join(HERE, 'server.mjs')],
  stderr: 'ignore',
});
const client = new Client({ name: 'hebrinex-smoke', version: '0.17.0' });

try {
  await client.connect(transport);

  const { tools } = await client.listTools();
  const names = tools.map((tool) => tool.name).sort();
  const expected = [
    'agent_audit',
    'agent_review',
    'approval_check',
    'close_cycle_check',
    'gate_check',
    'lock_acquire',
    'lock_release',
    'memory_route',
    'preflight_approve',
    'role_assume',
    'run_command',
    'session_contract',
    'session_usage',
  ];
  check(JSON.stringify(names) === JSON.stringify(expected), `tools registradas: ${names.join(',')}`);

  const contract = await client.callTool({ name: 'session_contract', arguments: {} });
  const contractPayload = parsePayload(contract);
  check(Boolean(contractPayload?.contract_text?.includes('Contrato de sesion:')), 'session_contract devuelve contrato armado');
  check(typeof contractPayload?.context_budget?.estimated_tokens === 'number', 'session_contract reporta presupuesto');

  const gates = await client.callTool({ name: 'gate_check', arguments: {} });
  const gatesPayload = parsePayload(gates);
  check(Array.isArray(gatesPayload?.gates) && gatesPayload.gates.length === 8, 'gate_check clasifica G5B..G5I');

  const route = await client.callTool({ name: 'memory_route', arguments: {} });
  const routePayload = parsePayload(route);
  check(['first_message', 'reentry_light', 'debug_log_intake', 'compactation_recovery'].includes(routePayload?.route), `memory_route decide ruta valida (${routePayload?.route})`);

  const closure = await client.callTool({ name: 'close_cycle_check', arguments: {} });
  const closurePayload = parsePayload(closure);
  check(typeof closurePayload?.pass === 'boolean' && Array.isArray(closurePayload?.gaps), 'close_cycle_check devuelve pass/gaps');

  const allowed = await client.callTool({ name: 'run_command', arguments: { command_text: 'git status --short' } });
  const allowedPayload = parsePayload(allowed);
  check(allowedPayload?.decision === 'allow' && allowedPayload?.execution?.attempted === true, 'run_command ejecuta comando allowlisteado via gateway');

  const blocked = await client.callTool({ name: 'run_command', arguments: { command_text: 'rm -rf /' } });
  const blockedPayload = parsePayload(blocked);
  check(blocked.isError === true && blockedPayload?.decision === 'block', 'run_command falla con block para comando peligroso');

  const badApproval = await client.callTool({ name: 'approval_check', arguments: { approval_id: 'APR-INEXISTENTE-000000', command_text: 'git push' } });
  const badApprovalPayload = parsePayload(badApproval);
  check(badApproval.isError === true && badApprovalPayload?.valid === false, 'approval_check rechaza approval inexistente');

  // session_usage: en una maquina con transcripts reporta totales y costo;
  // sin transcripts (p. ej. CI) debe fallar con error claro, nunca inventar datos.
  const usage = await client.callTool({ name: 'session_usage', arguments: {} });
  const usagePayload = parsePayload(usage);
  if (usage.isError === true) {
    check(
      ['transcripts_dir_not_found', 'no_transcripts_found', 'no_assistant_usage_in_transcript'].includes(usagePayload?.reason),
      `session_usage sin transcripts falla con razon clara (${usagePayload?.reason})`,
    );
  } else {
    check(
      typeof usagePayload?.totals?.output_tokens === 'number'
        && typeof usagePayload?.estimated_cost_usd === 'number'
        && typeof usagePayload?.turns?.assistant_messages === 'number'
        && usagePayload?.pricing_source === 'mcp/model-pricing.yaml',
      'session_usage reporta totales, turnos y costo estimado',
    );
  }

  const badSession = await client.callTool({ name: 'session_usage', arguments: { session_id: 'no-existe-000' } });
  const badSessionPayload = parsePayload(badSession);
  check(
    badSession.isError === true
      && ['transcript_not_found', 'transcripts_dir_not_found'].includes(badSessionPayload?.reason),
    'session_usage con session_id inexistente falla con error claro',
  );

  // Locks: acquire -> conflicto -> release. Los archivos L-*.lock.md del smoke
  // se limpian al final para no ensuciar el working tree.
  const lockFiles = [];
  const acquired = await client.callTool({ name: 'lock_acquire', arguments: { paths: ['orquestador/testing/mcp-smoke-lock-demo.txt'], reason: 'mcp smoke', ttl_minutes: 5 } });
  const acquiredPayload = parsePayload(acquired);
  check(acquired.isError !== true && /^L-/.test(acquiredPayload?.lock_id ?? ''), 'lock_acquire adquiere lock con lock_id');
  if (acquiredPayload?.lock_path) lockFiles.push(acquiredPayload.lock_path);

  const conflicted = await client.callTool({ name: 'lock_acquire', arguments: { paths: ['orquestador/testing/mcp-smoke-lock-demo.txt'], reason: 'mcp smoke conflicto' } });
  const conflictedPayload = parsePayload(conflicted);
  check(conflicted.isError === true && /lock_conflict/.test(conflictedPayload?.reason ?? ''), 'lock_acquire sobre path lockeado falla con lock_conflict');

  const released = await client.callTool({ name: 'lock_release', arguments: { lock_id: acquiredPayload?.lock_id ?? 'L-INVALID' } });
  const releasedPayload = parsePayload(released);
  check(released.isError !== true && releasedPayload?.status === 'released', 'lock_release libera el lock');

  const releaseMissing = await client.callTool({ name: 'lock_release', arguments: { lock_id: 'L-DOES-NOT-EXIST' } });
  const releaseMissingPayload = parsePayload(releaseMissing);
  check(releaseMissing.isError === true && releaseMissingPayload?.reason === 'lock_not_found', 'lock_release con id inexistente falla con lock_not_found');

  // Identidad de rol: rol invalido rechazado; reviewer no puede lockear
  // (deny edit_approved_write_set); implementer si, y el owner es el rol del
  // daemon aunque el caller no lo declare.
  const badRole = await client.callTool({ name: 'role_assume', arguments: { role_id: 'invented-role' } });
  check(badRole.isError === true && parsePayload(badRole)?.reason === 'unknown_role', 'role_assume rechaza rol fuera del agent-registry');

  const reviewerRole = await client.callTool({ name: 'role_assume', arguments: { role_id: 'reviewer' } });
  check(reviewerRole.isError !== true && parsePayload(reviewerRole)?.status === 'assumed', 'role_assume acepta reviewer');

  const reviewerLock = await client.callTool({ name: 'lock_acquire', arguments: { paths: ['orquestador/testing/mcp-smoke-role-demo.txt'] } });
  const reviewerLockPayload = parsePayload(reviewerLock);
  check(reviewerLock.isError === true && reviewerLockPayload?.reason === 'role_capability_blocked', 'lock_acquire como reviewer bloquea por capability');

  const implementerRole = await client.callTool({ name: 'role_assume', arguments: { role_id: 'implementer' } });
  check(implementerRole.isError !== true, 'role_assume acepta implementer');

  const implementerLock = await client.callTool({ name: 'lock_acquire', arguments: { paths: ['orquestador/testing/mcp-smoke-role-demo.txt'], ttl_minutes: 5 } });
  const implementerLockPayload = parsePayload(implementerLock);
  check(
    implementerLock.isError !== true
      && implementerLockPayload?.owner === 'implementer'
      && implementerLockPayload?.role_enforced === true,
    'lock_acquire como implementer usa el rol del daemon como owner',
  );
  if (implementerLockPayload?.lock_path) lockFiles.push(implementerLockPayload.lock_path);
  if (implementerLockPayload?.lock_id) {
    await client.callTool({ name: 'lock_release', arguments: { lock_id: implementerLockPayload.lock_id } });
  }

  // Agentes de rol: sin backend la tool debe fallar con instrucciones claras
  // (nunca inventar un veredicto); backend desconocido tambien falla claro.
  // No se corre un backend real en el smoke (costo/latencia no deterministas).
  const auditNoBackend = await client.callTool({ name: 'agent_audit', arguments: { plan_or_diff: 'plan de prueba smoke', backend: 'none' } });
  const auditNoBackendPayload = parsePayload(auditNoBackend);
  check(
    auditNoBackend.isError === true
      && auditNoBackendPayload?.reason === 'agents_backend_not_configured'
      && typeof auditNoBackendPayload?.how_to_configure === 'string',
    'agent_audit con backend none falla con instrucciones de configuracion',
  );

  const reviewUnknownBackend = await client.callTool({ name: 'agent_review', arguments: { diff: 'diff de prueba smoke', backend: 'backend-inventado' } });
  const reviewUnknownBackendPayload = parsePayload(reviewUnknownBackend);
  check(
    reviewUnknownBackend.isError === true
      && reviewUnknownBackendPayload?.reason === 'agents_backend_unknown'
      && Array.isArray(reviewUnknownBackendPayload?.known_backends),
    'agent_review con backend desconocido falla listando los backends conocidos',
  );

  const roleGuardedRun = await client.callTool({ name: 'run_command', arguments: { command_text: 'git status --short' } });
  const roleGuardedRunPayload = parsePayload(roleGuardedRun);
  check(
    roleGuardedRun.isError !== true && roleGuardedRunPayload?.role_enforced === true,
    'run_command con rol asumido pasa por agent-runtime (role_enforced=true)',
  );

  for (const lockFile of lockFiles) {
    try { rmSync(lockFile, { force: true }); } catch { /* best effort */ }
  }
} catch (error) {
  failures.push(`excepcion: ${error.message}`);
  console.error(`FAIL: excepcion durante smoke: ${error.stack || error.message}`);
} finally {
  try { await client.close(); } catch { /* ignore */ }
}

if (failures.length > 0) {
  console.error(`smoke FAILED (${failures.length}): ${failures.join(' | ')}`);
  process.exit(1);
}
console.error('smoke OK');
process.exit(0);
