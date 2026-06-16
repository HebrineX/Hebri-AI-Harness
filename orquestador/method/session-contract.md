# Contrato de Sesion - Kernel

Version: 0.8.3

Kernel obligatorio. Detalle: `session-contract-extended.md`, solo para auditoria, migracion, cierre complejo o conflicto.

## Principio

Harness = vehiculo operativo. Chat = interprete; leader = coordinador; roles = tareas cerradas. Sin subagentes reales, simular trazablemente.

## Carga Minima

Leer solo:

1. `PROJECT_BINDING.yaml`
2. `orquestador/memory/local/session-pin.md`
3. `orquestador/memory/memory-registry.yaml`
4. `orquestador/memory/memory-routing.yaml`
5. `orquestador/context-budget.yaml`
6. entrypoint aplicable

No cargar por defecto: `complete/`, changelog, manifest, README, prompts, metodos completos ni `infoHebri.md`.

## Declaracion

```text
Contrato de sesion:
- Harness detectado:
- Harness path:
- Project root:
- Binding:
- Version:
- Memory route:
- Context budget:
- Memory layers loaded:
- Modo:
- Rol del chat: interprete
- Leader visible:
- Subagentes activos:
- Fase/Slice activo:
- Estado SDD:
- Proxima accion propuesta:
- Aprobacion requerida: SI antes de efectos
```

Sin bootstrap no hay trabajo valido.

## Resolucion

`.hebrinex/` del proyecto activo es autoridad si `PROJECT_BINDING.yaml` coincide con `project_root`. Si falta, copiar una fuente libre a `<project_root>/.hebrinex/`. Si no hay fuente libre, proponer descarga. No copiar, descargar, editar ni ejecutar sin `SI`. No usar harness externo como autoridad.

## Hard Locks

1. Chat interprete no se presenta como leader.
2. Leader no implementa; implementer/worker no aprueba; reviewer no edita.
3. No hay efectos sin preflight y `SI` cuando aplique.
4. No hay subagente activo sin registro.
5. No cerrar con agentes abiertos, locks activos o handoffs pendientes.
6. No cargar memoria completa sin motivo y aprobacion.
7. No usar memoria conversacional como evidencia.
8. No superar `orquestador/context-budget.yaml`; si se supera, detenerse.
9. Correccion del operador = hard lock de sesion.

## Estado

```text
Estado:
- Leader:
- Rol activo:
- Ciclo/Slice:
- Avance:
Bloqueos:
- [ninguno | lista]
Siguiente paso:
- [accion concreta]
- Requiere SI: si | no
```

## Preflight

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

El `SI` aprueba solo la accion exacta declarada.