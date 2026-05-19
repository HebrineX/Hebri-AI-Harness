# Arquitectura AI Engineering

Esta guia convierte el harness metodologico en una arquitectura preparada para produccion cuando se conecten LLMs, tools o agentes ejecutables.

## Diagnostico de IA

La version actual del harness es fuerte como metodologia, pero debil como runtime:
- Los prompts existen como archivos, pero no tienen versionado uniforme ni schema de salida comun.
- La orquestacion vive en texto, no en contratos verificables.
- No hay cliente de modelo, retries, fallbacks, budgets ni cache definidos.
- Los estados SDD se describen, pero no hay registry machine-readable.
- La validacion depende del criterio del agente, no de schemas/gates.

## Principio Arquitectonico

El LLM es un adaptador, no el dueno del sistema. El dueno es el workflow SDD con contratos, policies y artefactos trazables.

## Capas Recomendadas

```text
src/
  domain/          reglas puras: roles, ownership, SDD, gaps
  application/     casos de uso: planear, crear spec, revisar, registrar gap
  workflows/       maquinas de estado y gates
  orchestration/   dispatcher/leader y ciclos multiagente
  prompts/         repositorio y renderer de prompts versionados
  llm/             ModelClient, retries, fallbacks, streaming, usage
  tools/           ToolRegistry, ToolPolicy, auditoria
  infrastructure/  filesystem, shell, git, artifact store
  interfaces/      CLI, HTTP, desktop, MCP
```

Reglas:
- `domain/` no importa `llm/`, `tools/`, `prompts/` ni `infrastructure/`.
- `llm/` no conoce reglas de negocio.
- `prompts/` no ejecuta tools.
- `tools/` siempre pasa por `ToolPolicy`.
- `workflows/` controla gates y aprobaciones humanas.

## Contratos Base

```ts
type RoleId = "leader" | "spec_author" | "implementer" | "reviewer" | "explorer" | "worker";
type AutonomyLevel = 0 | 1 | 2 | 3 | 4;

type ExecutionContext = {
  traceId: string;
  cycleId: string;
  actorRole: RoleId;
  mode: "automatico" | "manual";
  autonomyLevel: AutonomyLevel;
  workspaceRoot: string;
  harnessRoot: string;
};

type OperationalBrief = {
  objective: string;
  context: string[];
  restrictions: string[];
  relevantFiles: string[];
  exclusiveOwnership: string[];
  expectedOutput: string;
  verification?: string;
  risks: string[];
};
```

## Cliente de Modelo

```ts
type ModelRequest = {
  model: string;
  messages: Array<{ role: "system" | "user" | "assistant"; content: string }>;
  maxTokens?: number;
  temperature?: number;
  responseFormat?: { type: "json_schema"; schema: object };
  metadata: { traceId: string; promptId: string; promptVersion: string };
};

type ModelResponse = {
  text: string;
  usage: { inputTokens: number; outputTokens: number; totalTokens: number };
  finishReason: string;
  model: string;
};

interface ModelClient {
  complete(request: ModelRequest): Promise<ModelResponse>;
}
```

## Resiliencia

Politica recomendada para llamadas LLM:
- Timeout por request.
- Maximo 3 intentos.
- Backoff exponencial con jitter.
- Reintentar solo errores transitorios: timeout, 429, 5xx, conexion.
- No reintentar errores de schema sin reducir contexto o corregir prompt.
- Fallback de modelo por tarea: rapido/barato para exploracion, intermedio para implementacion, top-tier para arquitectura dificil.
- Circuit breaker por proveedor si hay fallas repetidas.
- Idempotency key por `traceId + promptId + inputHash`.

Pseudocodigo:

```ts
async function completeWithPolicy(req: ModelRequest): Promise<ModelResponse> {
  for (const model of modelFallbackChain(req)) {
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        return await timeout(client.complete({ ...req, model }), requestTimeoutMs);
      } catch (err) {
        if (!isTransient(err) || attempt === 3) break;
        await sleep(backoffWithJitter(attempt));
      }
    }
  }
  throw new Error("LLM_UNAVAILABLE_AFTER_FALLBACKS");
}
```

## Validacion de Salidas

Para salidas que alimentan workflow, exigir JSON schema o formato Markdown validable.

Validaciones minimas:
- JSON parseable cuando se solicite JSON.
- Campos obligatorios presentes.
- Rutas citadas existen o estan marcadas como `to_create`.
- Requirements usan IDs `R1`, `R2` y un solo `DEBE`.
- Tasks referencian requirements existentes.
- Evidence contiene comando, exit code y resumen.
- Respuesta vacia o generica bloquea el gate.

## Performance y Costos

Estrategias:
- Context slicing: cargar solo archivos requeridos por el brief.
- Prompt base comun: reglas globales referenciadas por ID, no repetidas en cada prompt largo.
- Budgets por rol: explorer bajo, implementer medio, reviewer medio, arquitectura alto solo con aprobacion.
- Cache por input deterministico: `promptId + promptVersion + inputHash + model + schemaVersion`.
- Cache de embeddings para busqueda semantica de docs/specs, invalidada por hash de archivo.
- Resumen incremental: registrar handoffs cortos en archivos, no pegar transcripciones.

## Observabilidad

Cada llamada a modelo o tool debe registrar:
- `traceId`, `cycleId`, `agentId`, `role`.
- prompt id/version.
- modelo usado y fallback si ocurrio.
- tokens input/output.
- latencia.
- retries.
- resultado del schema validation.
- artefactos escritos.

## Prompts Versionados

Frontmatter recomendado:

```yaml
---
id: hebrinex.implementer
version: 1.0.0
schema_version: 1
role: implementer
owner: Hebrinex
source: Hebri-AI-Structure
last_reviewed: 2026-05-19
---
```

Los prompts no deben hardcodear rutas si existe ruta canonica en `AGENTS.md`. Deben referenciar `.hebrinex/orquestador/sdd/specs/` y `.hebrinex/orquestador/sdd/progress/`.
