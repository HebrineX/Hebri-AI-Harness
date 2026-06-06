# Reentry Full

Ruta: `reentry_full`.
Presupuesto: <= 8000 tokens salvo `audit_global`.

Usar para auditoria global, migracion, reconstruccion historica, drift complejo o incidente con evidencia incompleta.

Requiere motivo. Requiere preflight y `SI` si implica lectura amplia, git, red, escritura o acciones posteriores.

Leer segun alcance declarado:
- local
- daily
- cycle
- project
- complete si fue aprobado
- state/registry
- gates/evidence del alcance declarado
- politica especifica del caso

Salida obligatoria:
- hechos observados;
- inferencias;
- contradicciones;
- gaps;
- plan de correccion;
- evidencia consultada;
- tokens estimados usados.