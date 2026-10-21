# Modos de Operacion

El harness tiene dos modos. El modo no cambia permisos de seguridad: cambia cuanta autonomia de decision tiene el leader antes de pedir aprobacion.

Antes de elegir modo se debe cumplir `session-contract.md`. El chat visible arranca como interprete; el leader debe quedar visible o pendiente de aprobacion.

## Modo Automatico

Objetivo: avanzar con fluidez cuando el operador ya aprobo un objetivo, una fase o un slice.

El leader puede hacer sin pedir aprobacion puntual:
- Leer archivos sin secretos dentro del proyecto y del perimetro permitido, incluido kernel/bootstrap, mediante tools nativos sin aprobacion adicional.
- Validar `PROJECT_BINDING.yaml`, `state.yaml`, `registry.yaml` y `PROGRESS.md` en modo read-only.
- Preparar diagnostico, plan, briefs y asignaciones.
- Decidir que rol corresponde segun el estado SDD.
- Detectar gaps, bloqueos y riesgos.
- Preparar la cola de trabajo antes de proponer acciones.
- Correr comandos de solo lectura dentro del proyecto (clase `read_only` de `orquestador/security/command-risk-registry.yaml`; 0.17.3).

El leader debe obtener preflight y `SI` para el alcance agrupado antes de:
- Editar o crear archivos.
- Correr comandos con efecto (cualquier clase distinta de `read_only`).
- Lanzar subagentes con escritura o verificacion.
- Llamar APIs/modelos pagados o externos.
- Crear, modificar o liberar locks.
- Cambiar estado SDD.
- Hacer git con efecto, red, deploy, instalacion de dependencias o acciones destructivas.

La aprobacion vigente cubre los pasos menores dentro del alcance; solo se renueva
si cambia el alcance o el riesgo. Lecturas acotadas sin secretos no requieren
preflight, `SI`, envelope ni Gateway obligatorio. Gateway es opcional y ejecuta
solo su gramatica restringida de lectura; nunca elude restricciones reales del host.

Formato obligatorio antes de avanzar:

```text
Modo: automatico
Rol del chat: interprete
Leader visible: si | no | pendiente
Project root: [ruta]
Harness path: [ruta]
Binding: source_template | bound | missing | mismatch
Accion propuesta: [accion concreta]
Alcance: [archivos/comandos/agentes]
External write scope: none | [rutas]
Riesgo: bajo | medio | alto
Verificacion: [como se confirma]
Resultado esperado: [salida]
Esperando: SI del operador
```

## Modo Manual

Objetivo: control total del operador.

Reglas:
- Cada alcance con efectos requiere aprobacion previa agrupada.
- Los comandos de lectura acotada sin secretos no requieren aprobacion previa.
- Cada slice se anuncia por separado.
- Cada handoff entre roles se anuncia por separado.
- Un `SI` puede cubrir varios pasos o slices si el preflight declara su alcance conjunto.
- El chat solo resume y pide aprobacion; no absorbe coordinacion si hay leader definido.

Formato obligatorio por paso:

```text
Modo: manual
Rol del chat: interprete
Leader visible: si | no | pendiente
Project root: [ruta]
Harness path: [ruta]
Binding: source_template | bound | missing | mismatch
Paso: [fase/slice/tarea]
Voy a hacer: [accion]
Por que: [razon]
Tocaria: [archivos/tools/comandos]
External write scope: none | [rutas]
No voy a tocar: [limites]
Criterio de salida: [verificacion]
Esperando: SI del operador
```

## Seleccion de Modo

Si el operador no define modo, usar `manual` para cualquier tarea con escritura, comandos con efecto, subagentes, git, red o cambios SDD. Usar `automatico` solo para exploracion documental de bajo riesgo o cuando el operador lo pida.

Cambiar de modo durante una sesion requiere registro en `PROGRESS.md` o en el handoff del ciclo y `SI` del operador.

## Re-entry

Despues de compactacion, cambio de cwd o cambio de proyecto, cualquier aprobacion pendiente expira. El leader debe completar el re-entry checklist, reconstruir estado y pedir un nuevo `SI` para acciones con efecto.

## Comandos de modo

`/harness manual` y `/harness automatico` solo preparan el cambio. Si modifican estado persistente, requieren preflight, `SI` y evidencia.
