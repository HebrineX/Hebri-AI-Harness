# Resolucion y Binding del Harness

Este documento define como se localiza, copia y valida `.hebrinex`.

## Principio

Un proyecto solo puede operar con el `.hebrinex` que vive dentro de su propia raiz y que esta vinculado mediante `PROJECT_BINDING.yaml`.

Un harness ubicado en otra carpeta nunca es autoridad operativa del proyecto activo. Solo puede ser usado como fuente libre para crear una copia local dentro del proyecto.

## Estados de Binding

```yaml
binding_mode: source_template | bound
```

### source_template

Uso permitido:

- editar el repo fuente del harness;
- copiarlo hacia un proyecto consumidor;
- auditar la metodologia del harness.

Uso prohibido:

- operar tareas de un proyecto consumidor;
- registrar ciclos de otro proyecto;
- guardar specs, locks, gates o estado de un proyecto externo.

### bound

Uso permitido:

- operar el proyecto cuyo `project_root` coincide exactamente con la raiz activa;
- registrar ciclos, approvals, locks, gates y evidencia del proyecto vinculado.

Uso prohibido:

- operar otro proyecto;
- ser usado como fallback por estar "cerca" o disponible localmente;
- recibir estado de un proyecto diferente.

## Algoritmo de Arranque

1. Determinar la raiz del proyecto activo.
2. Buscar `<project_root>/.hebrinex/`.
3. Si existe:
   - leer `PROJECT_BINDING.yaml`;
   - validar `binding_mode`;
   - si es `bound`, comparar `project_root`;
   - si no coincide, detener y pedir correccion.
4. Si no existe:
   - entrar en modo `bootstrap`;
   - buscar una fuente local libre con `binding_mode: source_template`;
   - copiarla a `<project_root>/.hebrinex/`;
   - vincular la copia al proyecto.
5. Si no existe fuente local libre:
   - proponer clonar `https://github.com/HebrineX/Hebri-AI-Harness`;
   - copiar o clonar el resultado en `<project_root>/.hebrinex/`;
   - vincular la copia.

## Binding Minimo

Todo proyecto consumidor debe tener:

```yaml
schema: hebrinex.project_binding
version: "0.1"
harness_version: "0.7.9"
binding_mode: bound
harness_instance_id: "HBX-..."
project_name: "nombre-del-proyecto"
project_root: "ruta-absoluta-del-proyecto"
repo_remote: "url-o-none"
source_repo: "https://github.com/HebrineX/Hebri-AI-Harness"
created_at: "YYYY-MM-DDTHH:mm:ssZ"
bound_at: "YYYY-MM-DDTHH:mm:ssZ"
```

## Regla de Fallback

Fallback no significa "usar otro harness local".

Fallback significa:

1. encontrar fuente libre;
2. copiarla al proyecto;
3. vincularla;
4. operar solamente desde la copia vinculada.

Si el agente no puede copiar o descargar, debe pedir al operador la ruta/contenido y no continuar.

## Anti-Contaminacion

Antes de escribir specs, progress, registry, locks o gates:

- `harness_path` debe estar dentro de `project_root`;
- `PROJECT_BINDING.yaml` debe estar en `bound`;
- `project_root` debe coincidir;
- el write-set no puede apuntar a otro `.hebrinex` salvo aprobacion explicita de migracion.

Si cualquiera de estas condiciones falla, el ciclo queda `blocked`.
