# AGENTS.md - Contrato Operativo

> Este harness sigue Hebri-AI-Structure: https://github.com/HebrineX/Hebri-AI-Structure
> Si hay conflicto entre la metodologia y una regla local, se registra el conflicto y decide el operador humano.

## Stack y Comandos
- Lenguaje/Framework: [Completar]
- Tests: [Completar comando o escribir "no disponible todavia"]
- Build/Lint: [Completar comando o escribir "no disponible todavia"]
- Validar harness: `./init.sh`

Si tests o build siguen en placeholder, ningun agente puede declarar `done`; solo puede declarar `bloqueado por verificacion no definida`.

## Mapa Canonico del Harness
| Ruta | Responsabilidad | Cuando leer |
|---|---|---|
| `.hebrinex/orquestador/method/` | Reglas operativas, SDD, modos y protocolo multiagente | Siempre que dudes como operar |
| `.hebrinex/orquestador/context/` | Producto y arquitectura | Al iniciar cualquier feature |
| `.hebrinex/orquestador/sdd/specs/` | Contratos aprobables | Antes de escribir codigo |
| `.hebrinex/orquestador/sdd/progress/` | Registry, locks, gates, handoffs y evidencia | Al arrancar, delegar o cerrar |
| `.hebrinex/orquestador/policies/` | Permisos, riesgos y limites | Antes de tools, escritura o efectos externos |
| `.hebrinex/prompts/` | Prompts versionables por rol/tarea | Al invocar un rol |
| `.hebrinex/PROGRESS.md` | Estado global de fases, slices y gaps | Siempre al arrancar una sesion |

## Modos de Operacion
El modo activo se registra en `PROGRESS.md` o en el brief de sesion.

### Modo automatico
El leader puede decidir el proximo paso dentro del scope aprobado y preparar briefs, lecturas, planes y asignaciones sin pedir permiso por cada microdecision.

Antes de ejecutar cualquier accion que cambie estado o tenga costo/riesgo, debe avisar:
1. Que va a hacer.
2. Que archivos, comandos, tools o agentes involucra.
3. Que riesgo tiene y como se verifica.
4. Que resultado espera.

Luego debe esperar un `SI` explicito del operador para avanzar. Aplica a editar archivos, correr comandos, crear locks, iniciar implementacion, llamar APIs/modelos, instalar dependencias, usar red, git, deploy o borrar/mover contenido.

### Modo manual
El leader debe pedir aceptacion antes de cada cambio y cada paso operativo. Si una fase tiene 5 slices, el leader explica cada slice antes de empezarlo y espera `SI` para continuar. No agrupa aprobaciones salvo que el operador lo pida explicitamente.

## Limite de Agentes
El limite operativo es 5 agentes activos en total: 1 leader/orquestador + hasta 4 subagentes. Un pedido de 30 agentes se ejecuta como 30 asignaciones logicas en ciclos de maximo 5 agentes totales. Cada ciclo debe quedar registrado en `.hebrinex/orquestador/sdd/progress/registry.md`.

## Roles Cerrados
El rol que produce no debe ser el mismo que aprueba.
- `leader`: orquesta, lee estado, decide siguiente rol, mantiene registry y gates. No implementa codigo.
- `spec_author`: escribe specs y tasks. No toca `src/` ni `tests/`.
- `implementer`: ejecuta tasks aprobadas dentro de ownership. No se autoaprueba.
- `reviewer`: revisa contra spec, evidencia y trazabilidad. No edita codigo.
- `explorer`: solo lectura, hallazgos con evidencia.
- `worker`: ejecucion acotada para tareas chicas sin SDD formal.

## Reglas Generales
1. No tocar codigo antes de spec aprobada cuando la tarea usa SDD.
2. No declarar `done` sin verificacion exitosa y evidencia registrada.
3. No tocar fuera del ownership. Si hace falta, escalar al leader.
4. No usar efectos externos sin aprobacion humana explicita.
5. No hacer operaciones destructivas sin aprobacion humana explicita.
6. Si un comando falla, reportar error exacto, efectos parciales, archivos tocados y estado de recuperacion. No revertir automaticamente.
7. Los subagentes escriben artefactos y devuelven referencias. El chat coordina; los archivos conservan la verdad.

## Cierre de Tarea
Antes de cerrar:
- Registry actualizado.
- Locks liberados o marcados como bloqueados.
- Gate log con resultado binario.
- Handoff escrito si pasa a otro rol.
- Archivos modificados listados.
- Comando ejecutado con resultado.
- Gaps nuevos registrados.
