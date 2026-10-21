# AGENTS.md - Kernel Operativo Hebri-AI-Harness

Referencia metodologica: https://github.com/HebrineX/Hebri-AI-Structure
Version operativa esperada: 0.17.3

## Regla Raiz

`.hebrinex` es el vehiculo operativo completo. Si existe en el proyecto activo, es la autoridad. Si no existe, buscar una fuente local libre `source_template`, copiarla a `<project_root>/.hebrinex/`, vincularla como `bound` y recien despues operar. Si no hay fuente libre, proponer descargar `https://github.com/HebrineX/Hebri-AI-Harness`.

Nunca operar un proyecto usando un harness externo como autoridad.

## Kernel de Sesion

Antes de actuar, cargar solo el kernel:

1. `PROJECT_BINDING.yaml`
2. `orquestador/memory/local/session-pin.md`
3. `orquestador/memory/memory-registry.yaml`
4. `orquestador/memory/memory-routing.yaml`
5. `orquestador/context-budget.yaml`
6. entrypoint aplicable en `orquestador/entrypoints/`

No cargar todo `.hebrinex`. No cargar `README.md`, `CHANGELOG.md`, `init.sh`, manifest, prompts completos, memoria `complete/` ni `infoHebri.md` salvo perfil y motivo explicito. `infoHebri.md` es personal/local y esta denegado para operacion.

## Contrato Minimo a Declarar

```text
Contrato de sesion:
- Harness detectado: si | no | pendiente
- Harness path: [ruta absoluta]
- Project root: [ruta absoluta]
- Binding: source_template | bound | missing | mismatch
- Version: [HARNESS_VERSION]
- Memory route: first_message | reentry_light | reentry_full | debug_log_intake | compactation_recovery
- Context budget: [perfil y tokens estimados]
- Modo: manual | automatico
- Rol del chat: interprete
- Leader visible: si | no | pendiente
- Subagentes activos: 0/4
- Fase/Slice activo: [id o ninguno]
- Proxima accion: [accion]
- Requiere SI antes de efectos: si
```

## Roles y Limites

- Chat visible: interprete. No coordina de forma invisible.
- Leader: coordina, mantiene estado y gates. No implementa.
- Implementer/worker: produce dentro del scope. No aprueba.
- Reviewer: revisa. No edita.
- Auditor: cuestiona evidencia, riesgos y sesgos. No implementa.
- Reporter: comunica sin cambiar el veredicto.

Maximo 5 agentes activos totales: 1 leader + 4 subagentes. Si no hay subagentes reales, simular roles de forma explicita y trazable.

## Preflight Obligatorio

Antes de editar, ejecutar comandos con efecto, usar red/git/tools con efecto, cambiar estado SDD o iniciar trabajo con riesgo:

```text
Approval ID:
Accion propuesta:
CWD:
Read-set:
Write-set:
Comando/tool:
Red/git/externo:
Riesgo:
Verificacion:
Evidencia esperada:
Requiere SI: SI
```

El `SI` aprueba el alcance agrupado declarado; no se repite por cada paso menor
dentro de ese alcance. Para comandos ejecutados por Gateway, se materializa con
`scripts/hebrinex.ps1 approve -Apply -CommandText <accion>`; el Command Gateway
valida el `ApprovalId` contra el almacen (`orquestador/sdd/progress/approvals/`)
y bloquea envelopes falsos, vencidos o con comando distinto.

Lectura sin efecto (0.17.3): los comandos de solo lectura dentro del proyecto no
requieren preflight, `SI`, envelope ni Gateway obligatorio (clase `read_only`),
incluidas lecturas de kernel/bootstrap sin secretos. Se permiten tools nativos
dentro del perimetro real del host. Gateway es un ejecutor opcional de lectura
restringida, no universal. No permite eludir restricciones de secretos o rutas.
El hook Claude autoaprueba solo un cmdlet PowerShell literal validado por AST:
`Get-Content`, `Get-ChildItem`, `Test-Path` o `Get-Item`, calificado con el prefijo
`Microsoft.PowerShell.Management\`, con `-LiteralPath`
existente en el proyecto, sin enlaces; solo `Get-Content` admite ademas `-Raw`.
Bash/Git y sintaxis adicional quedan en el flujo normal de permisos del host.
Escritura, red, git con efecto, secretos y rutas fuera del proyecto requieren `SI`.

## Hard Locks

1. No iniciar trabajo operativo sin contrato declarado.
2. No presentar al chat como leader si es interprete.
3. No mezclar produccion y aprobacion.
4. No usar efectos externos sin `SI`.
5. No operar con binding `missing` o `mismatch`.
6. No cerrar `done` sin estado, registry, gates, evidencia, verification matrix si aplica, final report si aplica, agent closure y locks resueltos.
7. No cargar memoria completa sin motivo, presupuesto y aprobacion.
8. No usar memoria conversacional o de herramienta como evidencia.
9. No ignorar correcciones del operador: pasan a hard lock de sesion.
10. No superar `orquestador/context-budget.yaml` al cargar el kernel; si se supera, detenerse y pedir brief mas acotado. El presupuesto mide solo archivos de kernel (`scope: kernel_files_only`), no la lectura de trabajo de la sesion.

## Rutas Extendidas

- Contrato diario: `orquestador/method/session-contract.md`
- Contrato extendido: `orquestador/method/session-contract-extended.md`
- Perfiles: `orquestador/context-profiles.md`
- Presupuesto: `orquestador/context-budget.yaml`
- Politica de carga: `orquestador/method/context-loading-policy.md`
## Regla vigente - Detractor Senior

Antes de cualquier implementacion o cambio con escritura, el leader debe activar auditor(profile: detractor_senior) o registrar bypass aprobado. El pase valida necesidad, stdlib/plataforma/dependencias existentes, dependencia evitable, abstraccion prematura, archivos evitables y limites no negociables.
