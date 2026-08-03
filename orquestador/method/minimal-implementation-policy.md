# Minimal Implementation Policy

Version: 0.17.0

Esta politica evita que el agente construya mas de lo necesario. Se ejecuta antes de cualquier implementacion o cambio con escritura mediante `auditor(profile: detractor_senior)`.

## Escalera Senior

Antes de escribir, responder en orden:

1. Hace falta construir esto?
2. Lo resuelve el lenguaje o stdlib?
3. Lo resuelve la plataforma, framework o motor nativo?
4. Lo resuelve una dependencia ya instalada?
5. Puede resolverse con menos archivos/codigo sin perder claridad?
6. Solo entonces: escribir la solucion minima correcta.

## No se simplifica

Nunca reducir codigo a costa de:

- validacion en bordes de confianza;
- manejo de errores que evita perdida de datos;
- seguridad;
- accesibilidad;
- trazabilidad SDD;
- evidencia verificable;
- contrato del harness;
- aprobacion humana.

## Gate obligatorio

`G3A_detractor_senior_pre_implementation` debe estar en `pass` antes de `G4_execution_complete` para cambios con escritura.

## Vias validas para satisfacer G3A

Cualquiera de las tres satisface el gate. La via del daemon es la unica
agnostica del host de IA; la nativa es una proyeccion opcional premium y la
simulacion manual sigue siendo valida como fallback universal:

1. Daemon MCP (recomendada, funciona en cualquier host con MCP): tool
   `agent_audit(plan_or_diff)` de `mcp/server.mjs`, con backend read-only
   configurado en `mcp/agents-backend.yaml`. El veredicto devuelto
   (`aceptar | simplificar | bloquear | pedir evidencia`) se registra como
   evidencia del gate.
2. Subagente nativo (solo hosts con subagentes reales, hoy Claude Code):
   `auditor-detractor` instalado en `.claude/agents/` via
   `scripts/install-host-integrations.ps1 -HostName claude -Apply`. El host
   enforcea tools read-only.
3. Simulacion manual (fallback universal): correr el rol de forma explicita y
   trazable con el prompt de `agents/detractor-senior.md` (o
   `prompts/audit/detractor-senior.prompt.md`), declarando la simulacion en el
   contrato de sesion y registrando el veredicto completo como evidencia.

Las tres vias derivan de la MISMA fuente unica (`agents/detractor-senior.md`);
si difieren, la fuente manda y los derivados se regeneran con
`scripts/build-instructions.ps1 -WriteOutputs`.

## Bypass excepcional

Solo con aprobacion explicita del operador:

```text
Bypass detractor_senior:
- Motivo:
- Riesgo:
- Aprobado por:
- Expira en:
```

El bypass no permite saltar seguridad, datos, accesibilidad, contrato ni evidencia.