# Preflight Template

Usar antes de comandos, ediciones, subagentes con escritura/verificacion, red, git o cambios SDD.

```text
Preflight:
- Approval ID: APR-XXX
- Modo: manual | automatico
- Rol solicitante: leader | human
- Accion propuesta: [accion exacta]
- CWD: [ruta]
- Read-set: [archivos/carpetas]
- Write-set: [archivos/carpetas]
- Comando/tool: [exacto o none]
- Red/git/externo: no | si, detalle
- Riesgo: bajo | medio | alto
- Verificacion: [como se valida]
- Evidencia esperada: [archivo/log/reporte]
- Requiere SI: si
```

Si el operador responde `SI`, ejecutar solo lo declarado. Si cambia algo, detener y emitir nuevo preflight.
