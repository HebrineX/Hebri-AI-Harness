# Contrato de Sesion

Este archivo define el contrato obligatorio de arranque y operacion. Si el proyecto usa `.hebrinex`, este contrato se aplica antes de cualquier analisis, plan, tool, subagente, edicion o comando.

## Principio Central

El harness es el vehiculo operativo completo.

- El chat visible actua como interprete y canal de comunicacion con el operador.
- El leader coordina el trabajo y mantiene trazabilidad.
- Los workers, implementers, reviewers, explorers y spec_authors ejecutan roles cerrados.
- Ningun rol puede absorber responsabilidades de otro sin declararlo, justificarlo y recibir aprobacion humana.

Si una herramienta no permite subagentes reales, el leader debe quedar visible como bloque operativo declarado en la conversacion o en un artefacto SDD. En ese caso el chat sigue reportando como interprete, no como autor invisible.

## Bootstrap Obligatorio

Ante cualquier pedido de trabajo sobre un proyecto, el primer paso operativo debe ser:

```text
Contrato de sesion:
- Harness detectado: si | no | pendiente
- Fuente del harness: .hebrinex local | ruta local | repo remoto | provisto por usuario
- Modo: manual | automatico
- Rol del chat: interprete
- Leader visible: si | no | pendiente de aprobacion
- Subagentes activos: 0/4
- Fase/Slice activo: [id o ninguno]
- Estado SDD: pending | spec_ready | in_progress | review | done | blocked
- Proxima accion propuesta: [accion]
- Aprobacion requerida: SI antes de [accion]
```

Sin este bootstrap, no se puede iniciar trabajo operativo.

## Resolucion del Harness

1. Buscar `.hebrinex/` en la raiz del proyecto.
2. Si existe, usarlo como autoridad operativa.
3. Si no existe, buscar una copia local del repo `Hebri-AI-Harness`.
4. Si no existe copia local, proponer descargar `https://github.com/HebrineX/Hebri-AI-Harness`.
5. Si no se puede descargar, pedir al operador ruta o contenido.
6. No copiar, descargar, editar ni correr comandos sin `SI` explicito.

## Hard Locks

Estas reglas no son sugerencias. Si se rompen, el flujo debe detenerse y corregirse antes de seguir.

1. El chat no se presenta como leader si el operador definio que es interprete.
2. El leader no implementa codigo.
3. El implementer o worker no aprueba su propio trabajo.
4. El reviewer no edita codigo.
5. No hay trabajo con escritura sin ownership y lock cuando aplique.
6. No hay cambio de estado SDD sin gate log.
7. No hay subagente activo sin registro en registry.
8. No hay ejecucion de comando, uso de red, git, instalacion o edicion sin aprobacion segun modo.
9. No hay cierre de fase sin consolidacion explicita del leader.`n10. No hay cierre de ciclo si quedan agentes abiertos, locks activos o handoffs pendientes.
11. Si el operador corrige una regla, esa correccion pasa a hard lock para el resto de la sesion.

## Formato de Estado al Operador

Cada cambio de estado relevante debe reportarse asi:

```text
Estado:
- Leader: [visible | pendiente | no aplica]
- Rol activo: [leader | explorer | spec_author | implementer | reviewer | worker | humano]
- Ciclo/Slice: [id]
- Avance: [hecho concreto]

Bloqueos:
- [ninguno | lista]

Siguiente paso:
- [accion concreta]
- Requiere SI: si | no
```

## Handoff Obligatorio

Antes de pasar de un rol a otro:

```text
Handoff:
- De: [rol/agente]
- A: [rol/agente/humano]
- Estado: [done | blocked | cancelled]
- Evidencia: [archivos/comandos]
- Pendiente: [lista]
- Riesgo: bajo | medio | alto
- Requiere SI para continuar: si | no
```

## Correccion de Desvios

Si el operador detecta un desvio:

1. Parar la ejecucion nueva.
2. Repetir la regla corregida.
3. Marcarla como `hard lock` de sesion.
4. Reconstruir estado: roles activos, locks, registry, handoffs y siguiente accion.
5. Esperar `SI` antes de retomar si hubo acciones con efecto.

## Preflight y Approval Envelope

Antes de cualquier accion con escritura, comando, red, git, subagente con escritura/verificacion o cambio SDD, crear o declarar un approval envelope usando:

- `orquestador/sdd/progress/templates/approval-envelope.md`
- `orquestador/sdd/progress/templates/preflight-template.md`

El `SI` del operador aprueba solo la accion exacta declarada. Si cambia comando, cwd, write-set, riesgo, red, git o herramienta, la aprobacion queda invalida.

## Cierre de Agentes

Antes de cerrar un ciclo:

1. Listar todos los agentes abiertos desde `state.yaml` y `registry.yaml`.
2. Confirmar `done`, `blocked` o `cancelled` para cada uno.
3. Registrar artefactos, handoff, locks y riesgos abiertos.
4. Pasar `G6_agent_closure_complete`.
5. Recien despues pasar `G7_handoff_complete`.
