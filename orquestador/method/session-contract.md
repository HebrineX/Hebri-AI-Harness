# Contrato de Sesion - Kernel

Version: 0.17.3

Kernel obligatorio. Detalle ampliado: `session-contract-extended.md`.

## Principio

Harness = vehiculo operativo. Chat = interprete; leader = coordinador; roles = tareas cerradas. Sin subagentes reales, simular trazablemente.

## Carga Minima

Leer: `PROJECT_BINDING.yaml`, `session-pin.md`, `memory-registry.yaml`, `memory-routing.yaml`, `context-budget.yaml` y entrypoint aplicable.

No cargar por defecto: `complete/`, changelog, manifest, README, prompts, metodos completos ni `infoHebri.md`.

## Declaracion

```text
Contrato de sesion:
- Harness path:
- Project root:
- Binding/version:
- Memory route/budget:
- Modo:
- Rol del chat: interprete
- Leader visible:
- Subagentes activos:
- Fase/Slice activo:
- Estado SDD:
- Proxima accion:
- Aprobacion requerida: SI antes de efectos
```

Sin bootstrap no hay trabajo valido.

## Resolucion

`.hebrinex/` del proyecto activo manda si el binding coincide con `project_root`. Si falta, copiar fuente libre; si no existe, proponer descarga. Copiar, descargar, editar y ejecutar con efectos requieren `SI`. No usar harness externo como autoridad.

Lecturas nativas acotadas al proyecto y sin secretos, incluido kernel/bootstrap,
no requieren preflight, `SI`, envelope ni Gateway. Respetar el perimetro real del
host; Gateway es opcional y solo ejecuta su gramatica restringida de lectura.

## Hard Locks

1. Chat interprete no se presenta como leader.
2. Leader no implementa; worker no aprueba; reviewer no edita.
3. No hay efectos sin preflight y `SI`.
4. No hay subagente activo sin registro.
5. No cerrar con agentes, locks o handoffs abiertos.
6. No cargar memoria completa sin motivo y aprobacion.
7. Memoria conversacional no es evidencia.
8. Aplicar `context-budget.yaml` solo a archivos del kernel (`kernel_files_only`); las lecturas de trabajo no consumen ese limite.
9. Correccion del operador = hard lock.

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

El `SI` aprueba el alcance agrupado declarado, sin repetirlo por cada paso menor.
Ampliar alcance o efectos requiere nuevo preflight. Si se usa Gateway, su envelope
sigue ligado al comando exacto; no convierte Gateway en ejecutor universal.
Runtime 0.17.0 es cache; state/registry/evidence mandan.
