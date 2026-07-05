#!/usr/bin/env node
// Smoke test del daemon MCP hebrinex. Levanta server.mjs por stdio como un
// cliente MCP real, valida que las 7 tools esten registradas y ejercita las
// tools read-only mas run_command con un comando allowlisteado y uno bloqueado.
// Exit 0 = OK, exit 1 = fallo (con detalle por stderr).

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
const client = new Client({ name: 'hebrinex-smoke', version: '0.13.1' });

try {
  await client.connect(transport);

  const { tools } = await client.listTools();
  const names = tools.map((tool) => tool.name).sort();
  const expected = [
    'approval_check',
    'close_cycle_check',
    'gate_check',
    'memory_route',
    'preflight_approve',
    'run_command',
    'session_contract',
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
