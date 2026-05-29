# Criterios de Riesgo y Escalada

Un agente debe escalar cuando el riesgo supera su autonomia o su ownership.

## Requiere Aprobacion Humana Explicita

1. Operaciones destructivas o irreversibles: `rm -rf`, `Remove-Item -Recurse`, borrado de DB, limpieza de volumenes Docker, sobrescrituras masivas, formateo, movimientos fuera del ownership.
2. Secretos y credenciales: leer, mover, imprimir, rotar o modificar `.env`, llaves, tokens, certificados o configuracion sensible.
3. Persistencia: migraciones, cambios de schema, borrado de datos, resets de DB.
4. Efectos externos: red no autorizada, deploys, mails, pagos, webhooks, APIs de terceros.
5. Git remoto: push, force-push, tags remotos, releases, merge de PR.
6. Cambios de contrato publico: APIs, interfaces compartidas, formatos persistidos.
7. Instalacion de dependencias o herramientas nuevas.
8. Artefactos derivados con impacto publico o historico: changelog, release notes, README versionado, deploy docs historicos, roadmap consolidado o auditorias que declaran cumplimiento.
9. Deploys, migraciones o CI/pipelines que afectan entornos, datos o release publico.
10. Presets por IA que cambian permisos, autonomias o reglas de aprobacion.

## Puede Escalar Solo al Leader

- Conflicto de ownership.
- Spec ambigua.
- Falta de archivos esperados que son triviales de crear.
- Necesidad de serializar agentes.
- Falta de evidencia o handoff incompleto.
- Reintentos agotados en una tarea no destructiva.
- Contradiccion entre `git log`, `PROGRESS.md`, registry y ciclos al reconstruir historia.
- Drift entre version operativa, binding, README, changelog, prompts e `init.sh`.
- Backlog P0/P1/P2 sin evidencia suficiente.

## Bloqueos Tipicos

| Tipo | Quien decide |
|---|---|
| Decision de producto | Humano |
| Riesgo destructivo | Humano |
| Credenciales | Humano |
| Scope/ownership | Leader |
| Verificacion no definida | Leader o humano si bloquea cierre |
| Spec contradictoria | Spec author + humano |
| Historia/versionado contradictorio | Auditor release + humano si cambia release publico |
| Deploy/migracion sin evidencia | Leader + humano si afecta entorno externo |
| Preset de IA inseguro | Auditor harness_compliance + humano |

## Regla de No Sustitucion

El leader no puede reemplazar aprobacion humana en acciones destructivas, externas, sensibles o de persistencia. Puede preparar la explicacion y pedir el `SI`; no puede concederselo a si mismo.
