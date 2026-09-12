# Arquitectura y contratos propuestos

Estado: implementación local hasta P06; lifecycle instalado P07-P08 pendiente. Este documento distingue contratos ya implementados de objetivos futuros. La CLI estable legacy se conserva junto a `central1`. Los ejemplos JSON contienen identidades ficticias y no constituyen approvals ni evidencia runtime.

## 1. Tres raíces y autoridad

| Raíz | Ubicación propuesta | Propietario / escrituras |
|---|---|---|
| `InstallRoot` | `%ProgramFiles%\Hebri-AI-Harness` | Windows Installer administra payload. Usuarios consumidores: lectura/ejecución. Runtime de proyectos: ninguna escritura. |
| `ProjectRoot` | Raíz explícita de un proyecto, normalizada y validada contra su binding. | Operador y herramientas autorizadas para ese proyecto. No se deduce exclusivamente del CWD del servidor. |
| `InstanceRoot` | `<ProjectRoot>\.hebrinex\instance` | Estado privado de ese proyecto bajo autorización y locks. |

El binding nuevo vive en `<ProjectRoot>\.hebrinex\binding.json`. El binding confirma identidad y contrato; no puede redirigir `InstallRoot` a un script arbitrario. La ruta del producto se obtiene del launcher/registro del instalador y se verifica su pertenencia e integridad. Overrides de desarrollo, si se implementan, requieren modo explícito, rutas aprobadas y señalización visible; nunca son fallback en producción.

La instalación por máquina es la decisión base. Un alcance por usuario sería otro diseño de packaging, ACL y PATH; no mezclar ambos de forma automática. Una instalación/upgrade elevada no descubre ni ejecuta proyectos de otros usuarios. El catálogo nunca otorga autorización ni es una lista confiable para ejecutar migraciones elevadas.

## 2. Layout y clasificación de rutas

```text
InstallRoot/
  bin/                         launcher estable
  engine/                      scripts, módulos y MCP opcional
  contracts/                   schemas, políticas, roles y defaults inmutables
  templates/                   semillas sin identidad ni datos personales
  payload-manifest.json        rutas, clases, tamaños y hashes del producto
  release.json                 versión, línea API y schemas compatibles

ProjectRoot/
  .gitignore                   excluye .hebrinex/
  .hebrinex/
    binding.json               identidad y compatibilidad
    instance/
      context/ memory/         información de este proyecto
      sdd/progress/            estado, approvals/, locks/ y evidence/ existentes
      migration/              backups/ y reports/ de migración existentes
      runtime/                caché no autoritativa y journals/ de efectos nuevos
      integrations/            configuración específica sin secretos embebidos

%LOCALAPPDATA%/Hebri-AI-Harness/
  projects/<projectId>.json     entradas recuperables del usuario actual
  logs/                       diagnóstico del launcher sin secretos
```

Los nombres finales del payload se fijan en P01 y se prueban en P06. No se mueve nada por documentar este árbol. Shims o archivos de integración en el proyecto sólo se crean si el host los necesita; deben ser mínimos, inventariados y regenerables. No se replica `agents/`, `prompts/`, `scripts/` ni el motor completo en cada proyecto nuevo.

Se preservan las rutas de instancia ya canónicas: `instance/sdd/progress/{approvals,locks,evidence}` e `instance/migration/{backups,reports}`. La centralización no justifica moverlas otra vez. `runtime/journals` es una propuesta nueva que debe mapearse explícitamente; no sustituye evidencias ni reportes existentes. `CatalogRoot` es una raíz auxiliar derivada de `%LOCALAPPDATA%/Hebri-AI-Harness/projects` para el usuario actual, nunca una cuarta autoridad del proyecto ni una ruta arbitraria recibida del binding. Un archivo por proyecto limita el daño de una entrada corrupta; no hay dos catálogos autoritativos.

El manifest clasifica cada ruta como `product`, `template`, `instance`, `integration`, `catalog` o `denied`. Default: `denied`. La regla más específica prevalece sobre una carpeta compartida; una carpeta mixta no puede compartirse completa. `SHARED_MANIFEST.yaml` actual sirve como entrada de inventario, no como prueba de que todas las llamadas ya respetan la separación. Paths personales, estados activos, approvals, locks, logs, backups, caches y credenciales quedan fuera del payload.

## 3. Resolver único

Contrato lógico propuesto: `ResolveHarnessContext(request)` devuelve raíces verificadas, identidad, versión y diagnóstico; `ResolveHarnessPath(context, logicalPath, access)` devuelve una ruta o error. Las implementaciones PowerShell/Node no mantendrán mapas divergentes: usarán el mismo manifest/schema y fixtures de conformidad. La elección de bridge se decide midiendo simplicidad y latencia; no requiere un servicio residente.

Secuencia obligatoria:

1. Validar schema y modo; identificar el proyecto desde un argumento explícito o un descubrimiento documentado que el usuario pueda inspeccionar.
2. Resolver ruta absoluta y contención con frontera de separador; comprobar componentes reparse/junction/symlink. `StartsWith` de texto sin frontera no demuestra pertenencia.
3. Detectar layout: binding JSON central, binding YAML legacy o ausencia. Si aparecen dos bindings activos contradictorios, devolver conflicto; no elegir por fecha.
4. Validar identidad, `project_root`, schemas y compatibilidad. Un proyecto movido se diagnostica y requiere rebind aprobado; no se cambia silenciosamente.
5. Resolver `InstallRoot` desde origen confiable del launcher y verificar manifest/versión; resolver `InstanceRoot` desde el contrato local.
6. Mapear cada path según clase y operación. Un consumidor no obtiene un permiso de escritura sobre `product` aunque pueda leerlo.
7. Revalidar raíces y recursos inmediatamente antes del efecto para reducir cambios entre check y apply. Un cambio relevante invalida plan y approval.

No se seguirá un enlace que escape del scope para copiar, restaurar, borrar o cargar código. Las excepciones a reparse points requieren diseño y pruebas propios; el default es rechazarlos en rutas de efecto. Las protecciones del gateway no evitan que una herramienta externa del mismo usuario edite directamente un archivo: esa limitación debe declararse por adaptador y detectarse mediante drift cuando corresponda.

## 4. Binding nuevo y compatibilidad legacy

Ejemplo de contrato objetivo; `0.18.0` es una versión ilustrativa, no una release aprobada:

```json
{
  "schema": "hebrinex.binding",
  "schema_version": 1,
  "layout": "central_instance",
  "project_id": "9c99b8f8-213b-4d47-9f79-d3345befa001",
  "instance_id": "ba68fbf9-541b-407b-a657-08e17d1fa002",
  "project_root": "C:\\Work\\Example",
  "instance_relative_path": ".hebrinex/instance",
  "required_engine": {
    "api_line": "1",
    "minimum_engine_version": "0.18.0"
  },
  "state_schema_version": 1,
  "last_verified_engine_version": "0.18.0",
  "created_at": "2026-09-08T00:00:00Z",
  "updated_at": "2026-09-08T00:00:00Z"
}
```

Reglas del schema: campos obligatorios tipados; `additionalProperties: false` en contratos cerrados; IDs no vacíos y únicos; rutas relativas sin traversal; timestamps UTC; versiones con parser explícito; `layout` enum. `last_verified_engine_version` es evidencia histórica, no un pin exacto ni autorización para usar cualquier versión.

Una versión activa por línea API compatible es el objetivo inicial; no se promete side-by-side automático. El motor declara schemas de binding/estado soportados y debe probar compatibilidad hacia atrás. Un upgrade que cambie línea API o retire schemas necesita una decisión explícita de compatibilidad. Un proyecto incompatible falla cerrado sin tocar datos; puede quedar temporalmente indisponible hasta disponer de motor compatible o migración aprobada. El diseño no promete retener versiones antiguas que el MSI no administra.

Los consumidores actuales con `PROJECT_BINDING.yaml` siguen una ruta legacy identificable. Se reutiliza el parser existente sólo mientras alcance los schemas soportados y pase fixtures; no se agrega una dependencia YAML por conveniencia. Migración: leer y validar YAML, inventariar drift, producir plan/backup, crear JSON y nueva instancia de forma transaccional, verificar y dejar evidencia del origen. Retirar la autoridad del YAML anterior requiere la misma transacción; coexistencia ambigua bloquea. Las rutas desconocidas se conservan o se elevan como conflicto, nunca se descartan por no estar en el nuevo manifest.

## 5. Servicio lógico y protocolo JSON

El núcleo es un servicio lógico invocable bajo demanda desde CLI, PowerShell y MCP opcional. No requiere daemon, puerto, cuenta de servicio ni base de datos para la operación base. Cada invocación recibe proyecto y operación explícitos; una conexión MCP no comparte estado mutable entre proyectos por un ROOT global.

Operaciones candidatas: `context.resolve`, `project.inspect`, `project.bind`, `catalog.reconcile`, `migration.plan`, `migration.apply`, `operation.recover`, `contract.check`. Son nombres de diseño; no se presentan como comandos existentes. Un adaptador traduce el protocolo sin ganar capabilities adicionales.

Ejemplo de request de planificación, sin autorización de escritura:

```json
{
  "schema": "hebrinex.operation.request",
  "schema_version": 1,
  "request_id": "3e5a3c34-9b84-4562-914b-d129b6223001",
  "operation_id": "43527ca3-0b73-42d9-9264-55d607942002",
  "operation": "project.bind",
  "mode": "plan",
  "project_root": "C:\\Work\\Example",
  "expected_project_id": null,
  "actor": {
    "agent_id": "example-implementer",
    "role": "implementer"
  },
  "parameters": {
    "layout": "central_instance"
  },
  "approval_id": null,
  "expected_plan_sha256": null
}
```

El schema restringe `operation`, `mode`, parámetros y campos según operación. El servidor deriva identidad del actor desde el canal autenticado/capability vigente, no confía en la declaración del cliente. En `apply`, se requieren approval y hash del plan vigente. El servidor recalcula efectos y condiciones; no permite que el request declare un write-set más pequeño que sus efectos reales.

Ejemplo de resultado de planificación:

```json
{
  "schema": "hebrinex.operation.result",
  "schema_version": 1,
  "request_id": "3e5a3c34-9b84-4562-914b-d129b6223001",
  "operation_id": "43527ca3-0b73-42d9-9264-55d607942002",
  "status": "planned",
  "exit_code": 0,
  "writes_performed": false,
  "approval_required": true,
  "plan": {
    "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "preconditions": ["project_exists", "binding_absent", "engine_compatible"],
    "effects": [
      {"kind": "create", "root": "ProjectRoot", "path": ".hebrinex/binding.json"},
      {"kind": "create_directory", "root": "InstanceRoot", "path": "."},
      {"kind": "merge_if_missing", "root": "ProjectRoot", "path": ".gitignore"},
      {"kind": "catalog_upsert", "root": "CatalogRoot", "path": "9c99b8f8-213b-4d47-9f79-d3345befa001.json"}
    ]
  },
  "actual_effects": [],
  "evidence": [],
  "error": null
}
```

El hash de ejemplo es ficticio. El hash real cubre representación canónica documentada: operación, scope/raíces, identidad, versiones, precondiciones, inputs y efectos. Ningún approval se crea a partir del resultado anterior. Un plan sólo lectura puede devolverse por stdout; persistirlo es otro efecto que debe figurar en el scope.

El ID nuevo del proyecto se asigna al plan de bind antes del approval y no cambia al aplicar. El catálogo es un efecto adicional dentro del plan aprobado. Si su actualización falla tras crear la instancia, registrar resultado parcial y recovery/reconcile; no borrar datos válidos sólo para fingir atomicidad entre volúmenes. P02/P04 fijan la compensación y prueban que una entrada ausente no invalida el binding ni habilita otro proyecto.

## 6. Errores, exit codes y observabilidad

El dispatcher nuevo tendrá una taxonomía estable; la CLI existente conservará sus códigos hasta definir una traducción compatible en P04. Propuesta a congelar en P00/P01:

| Exit code nuevo | Error semántico | Conducta |
|---|---|---|
| 0 | Sin error | `planned`, `applied` o `unchanged`; nunca mezclar con `not_run`. |
| 2 | `INVALID_REQUEST` | Input/schema inválido; indicar campo sin exponer secretos. |
| 3 | `CONTEXT_NOT_FOUND` | Binding/motor/recurso ausente; indicar siguiente paso. |
| 4 | `INCOMPATIBLE_CONTRACT` | Versión/schema no soportado; no migrar automáticamente. |
| 5 | `AUTHORIZATION_DENIED` | Falta capability/approval válido o path prohibido; cero efectos nuevos. |
| 6 | `CONFLICT` | Drift, lock, identidad o condición cambió; replanificar. |
| 7 | `INTEGRITY_FAILURE` | Hash, paquete o contención inválidos; bloquear. |
| 8 | `RECOVERY_REQUIRED` | Efecto parcial conocido; enlazar journal y recuperación. |
| 10 | `OPERATION_FAILED` | Error no recuperado por la operación; preservar evidencia. |

Cada error contiene `code`, `message`, `operation_id`, `retryable`, `next_action` y referencias de evidencia. `retryable` no habilita repetir efectos sin revalidar. Los logs usan correlación, tiempos, duración y conteos; omiten tokens, credenciales, contenidos personales y comandos con secretos. Una falla tras escribir no puede declararse `writes_performed: false`.

## 7. Approvals y transacciones

La aprobación se vincula a: ID, autoridad/actor verificable, acción exacta, project/instance IDs, raíces, write-set, red/procesos/privilegios, hash del plan, revisión de inputs, emisión, vencimiento y regla de consumo. El gateway valida esos campos al aplicar. Un texto en un archivo, un `SI` inventado por agente o un approval de otra acción no sirve. Los registros documentales de este directorio no alimentan ese almacén.

Protocolo propuesto para efectos de archivo:

1. Validar aprobación y precondiciones; adquirir lock por recursos afectados, con propietario y operación.
2. Revalidar raíces, versiones y hashes; preparar journal y backup con checksums en la instancia, dentro del scope autorizado.
3. Preparar cambios en staging del mismo volumen y validar contenido antes del commit.
4. Aplicar escrituras atómicas cuando la plataforma lo permita y registrar cada paso duradero. La atomicidad de un archivo no garantiza transacción de varios archivos.
5. Verificar postcondiciones; marcar `committed` sólo cuando coinciden. Registrar consumo de approval y evidencia; liberar locks.
6. Ante falla, marcar estado recuperable; rollback sólo si hashes actuales permiten restaurar sin pisar cambios externos. Si no, bloquear y pedir decisión con diff concreto.

Estados del journal: `prepared`, `applying`, `committed`, `rolling_back`, `rolled_back`, `recovery_required`. Incluye schema, operación, proyecto, plan/approval, pre/post hashes, backups, pasos y resultados. Una recuperación tras corte de proceso lee journal y locks persistidos; no presume que un lock viejo está abandonado sólo por su edad. Idempotencia se prueba con la misma operación y evidencia, no con repetición ciega.

El estado de autorización se registra por separado: un approval puede estar pendiente, vigente, consumido, revocado o vencido según su contrato. `approved` no es estado del journal y no se infiere de `prepared`. El estado de resultado de una operación (`planned`, `applied`, `unchanged`, `blocked` o `failed`) tampoco reemplaza el progreso duradero del journal.

El catálogo local tiene su propio lock y transacción por usuario. Reconciliarlo requiere un listado autorizado de proyectos; no escanea perfiles ajenos. Pérdida del catálogo no pierde la autoridad ni los datos de cada binding.

## 8. MSI, runtimes y mantenimiento

El MSI posee únicamente archivos/registro/launcher del producto. Usa componentes estables, rutas explícitas y manifest reproducible. Preferir mecanismos declarativos de Windows Installer; custom actions que ejecutan proyectos o descargan dependencias quedan fuera del diseño base. No ejecutar `init.sh` durante instalación: su suite incluye efectos de prueba y supuestos de repositorio.

P06 fija versiones soportadas de Windows/arquitectura/PowerShell y decide prerequisito versus runtime incluido. No asumir que Windows trae `pwsh`. MCP/Node es opcional; si se ofrece offline, su runtime/dependencias, licencias y hashes deben estar resueltos antes de aceptar esa feature. No ejecutar `npm install` con red en la máquina del usuario como reparación implícita. Bash no será requisito para comandos base Windows; los scripts POSIX se conservan para sus plataformas verificadas.

- **Upgrade:** reemplaza producto dentro de una línea compatible, valida sus propios archivos y no migra schemas de proyectos. Compatible no significa probado hasta T07.1. Un cambio de línea mayor necesita plan específico.
- **Repair:** restaura componentes del producto; no reconstruye estado ni pisa integraciones personalizadas.
- **Uninstall:** retira sólo recursos administrados; preserva proyectos, `.hebrinex`, evidencia y backups. Limpieza de datos es una acción distinta y explícita.
- **Rollback de producto:** comportamiento de Windows Installer probado con fallas inyectadas. Volver a una versión anterior requiere compatibilidad y autorización; no equivale a restaurar estado de una instancia.

La reproducibilidad distingue payload sin firma (inventario/contenido determinista) del MSI y del artefacto firmado con timestamp, cuyos bytes pueden variar. P06 fijó WiX 5.0.2, Roslyn 5.3 del SDK 10.0.204, target .NET Framework 4.8 y Windows PowerShell 5.1 para el candidato local x64. El payload fue reproducible; los dos MSI tuvieron contenido lógico equivalente pero bytes distintos. Firma, revisión externa de distribución/licencia, Node/MCP redistribuible y aceptación en VM permanecen abiertas para P07-P09.

## 9. Límites y criterio de simplicidad

Reutilizar PowerShell, JSON, hashing y capacidades del sistema existentes. No crear un segundo framework de permisos, resolver o memoria si el actual puede extraerse con pruebas. No agregar servicio Windows, sincronización remota, telemetría externa, embeddings ni base de datos sin necesidad medida, alternativa evaluada y autorización. La extracción debe reducir mapas duplicados y puntos de confianza, no sólo mover archivos a Program Files.
