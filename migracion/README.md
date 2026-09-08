# Plan de migración a instalación central

Estado: propuesta revisada; implementación pendiente · Fecha de corte: 2026-09-08 · Base inspeccionada: Harness `0.17.1`.

El estado documental refleja los dictámenes independientes de leader y auditor comunicados por el coordinador, con sus ajustes confirmados. El autor no aprueba su propia producción ni autoriza implementación mediante este cambio de metadata.

Este directorio contiene un plan ejecutable por un equipo distinto del que realizó el análisis. Propone instalar el motor del Harness una vez en Windows y mantener en cada proyecto solamente su vínculo, contexto y estado. No instala software, no migra proyectos y no modifica la autoridad operativa actual del repositorio.

La creación de estos documentos fue solicitada por el operador. El `SI` previo `A-20260906-RO-01` autorizó una auditoría de lectura; no autoriza las implementaciones descritas aquí. Cada fase con efectos requiere su propio preflight, alcance concreto y aprobación verificable. Los registros de `operacion/` siguen este plan documental; no sustituyen los approvals, gates ni estados del Harness activo.

## Resultado que debe obtener el equipo

Una instalación central con un launcher estable; instancias aisladas por proyecto; contratos de resolución, autorización, contexto y agentes verificables; migración reversible de consumidores existentes; y un MSI probado en instalación limpia, actualización, reparación y desinstalación. La selección de proveedor o modelo debe ser explícita y evaluada: ningún resultado depende de una persona, un agente concreto o de recordar esta conversación.

El diseño separa tres raíces: `InstallRoot`, propiedad del instalador; `ProjectRoot`, el repositorio consumidor; e `InstanceRoot`, el estado privado de ese proyecto. Los procesos de un consumidor no escriben en el motor instalado. Un catálogo local facilita descubrir proyectos, pero la evidencia del proyecto sigue siendo la autoridad. No se exige un daemon permanente ni una base vectorial.

## Cómo comenzar sin cargar todo

1. Leer este archivo y [operacion/state.json](operacion/state.json). Identificar fase, bloqueos y siguiente acción.
2. Consultar [ROADMAP.md](ROADMAP.md) y abrir únicamente el archivo de la fase activa bajo `fases/`.
3. Cargar los requisitos y contratos enlazados por esa fase, con un presupuesto de contexto registrado según [AGENTES-CONTEXTO.md](AGENTES-CONTEXTO.md).
4. Reconstruir evidencia actual, revisar el preflight y obtener autorización para los efectos exactos. Un estado `planned`, un ejemplo o un dictamen técnico favorable no equivale a un `SI`.
5. Implementar con rol separado del reviewer; ejecutar la validación autorizada; dejar evidencias y un handoff que funcione sin chat previo.

Si el estado o las referencias contradicen el árbol actual, detener la parte dependiente, registrar la contradicción y replanificar. No completar campos por inferencia ni arrastrar una aprobación de una fase anterior.

## Documentos de consulta

| Documento | Cuándo cargarlo |
|---|---|
| [ROADMAP.md](ROADMAP.md) | Dependencias, orden y puertas de avance. |
| [REQUISITOS.md](REQUISITOS.md) | Requisitos R01–R18 y aceptación; cargar los de la fase. |
| [ARQUITECTURA-CONTRATOS.md](ARQUITECTURA-CONTRATOS.md) | Raíces, resolver, binding, API, efectos, MSI y compatibilidad. |
| [AGENTES-CONTEXTO.md](AGENTES-CONTEXTO.md) | Roles, task packs, límites, handoff y evaluación de modelos. |
| [VALIDACION.md](VALIDACION.md) | Pruebas propuestas, evidencia y criterios de PASS/FAIL. |
| [FUENTES-DECISIONES.md](FUENTES-DECISIONES.md) | Evidencia del repositorio, decisiones y pendientes. |
| [operacion/README.md](operacion/README.md) | Semántica de los registros y reglas de actualización. |

## Qué está observado y qué falta probar

La base inspeccionada declara versión `0.17.1`; el binding raíz es `source_template`, mientras el registro de memoria declara `bound`. El manifest inventariado contiene 397 archivos y 1.049.826 bytes. Son medidas estáticas, no el tamaño de un MSI ni una medición de ahorro. El kernel `first_message` se estimó en 1.603 tokens usando caracteres/4; esa cuenta excluye el contrato visible y no equivale a tokens reales del proveedor.

Existen un manifest de separación shared/instance, CLI, módulos de rutas, migración, validadores y CI. También persisten rutas que suponen scripts completos dentro de `.hebrinex`, remapeos duplicados y pruebas negativas que sólo comparan textos. La CI observada corre en Ubuntu. No se encontró packaging MSI/WiX en el alcance de búsqueda documentado. Los detalles y límites están en [FUENTES-DECISIONES.md](FUENTES-DECISIONES.md).

No se ejecutaron pruebas runtime en esta auditoría. Todos los casos de [VALIDACION.md](VALIDACION.md) comienzan en `not_run`. El plan no certifica seguridad, compatibilidad Windows, funcionamiento offline, ahorro de contexto ni calidad equivalente entre modelos.

## Reglas para continuar

- Leader coordina; implementer produce; reviewer revisa; auditor cuestiona riesgos. Nadie aprueba su propia producción.
- Un cambio del diseño que afecte raíces, autorización, aislamiento, compatibilidad o permisos vuelve al gate correspondiente.
- Cada fase identifica read-set, write-set, pruebas, rollback y evidencia. No se permite “ejecutar todo el roadmap” como aprobación implícita.
- La reducción de contexto se acepta sólo con corrección y gates preservados; un porcentaje de ahorro sin benchmark queda como hipótesis.
- La salida de P09 requiere todas las aceptaciones aplicables verificadas, riesgos pendientes resueltos o aceptados expresamente, documentación reproducible y cierre de agentes/locks.

La próxima acción es leer [P00](fases/P00-baseline-y-contrato.md) y preparar su preflight concreto. El inicio de implementación permanece pendiente de ese preflight y un `SI` específico.
