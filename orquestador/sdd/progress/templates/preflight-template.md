# Preflight Template

Usar antes de comandos, ediciones, subagentes con escritura/verificacion, red, git o cambios SDD.

```text
Preflight:
- Approval ID: APR-XXX
- Modo: manual | automatico
- Rol solicitante: leader | human
- Accion propuesta: [accion exacta]
- CWD: [ruta]
- Project root: [ruta]
- Harness path: [ruta]
- Binding status: source_template | bound | missing | mismatch
- Read-set: [archivos/carpetas]
- Write-set: [archivos/carpetas]
- External write scope: none | [rutas externas aprobadas]
- Comando/tool: [exacto o none]
- Red/git/externo: no | si, detalle
- Riesgo: bajo | medio | alto
- Verificacion: [como se valida]
- Evidencia esperada: [archivo/log/reporte]
- Invalidacion: cambia comando/cwd/project_root/harness_path/binding/write-set/read-set/scope externo/red/git/riesgo
- Requiere SI: si
```

Si el operador responde `SI`, ejecutar solo lo declarado. Si cambia algo, detener y emitir nuevo preflight.

No se acepta preflight retroactivo. El preflight debe existir antes del `SI`.

Commit y push van separados. Push siempre declara `git_remote`.
