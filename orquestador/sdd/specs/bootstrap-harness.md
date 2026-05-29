# Spec Bootstrap Harness

Esta spec describe como crear o regenerar una instancia del harness actual. No se carga en operacion diaria; solo se lee con el perfil `bootstrap`.

## Autoridad Actual

Para uso operativo, la autoridad vigente es:

- `PROJECT_BINDING.yaml`
- `AGENTS.md`
- `README.md`
- `init.sh`
- `orquestador/harness-manifest.txt`
- `orquestador/method/session-contract.md`
- `orquestador/method/harness-resolution.md`
- `orquestador/method/multiagent-protocol.md`
- `orquestador/context-profiles.md`

## Uso

1. Leer `orquestador/context-profiles.md` perfil `bootstrap`.
2. Leer `PROJECT_BINDING.yaml`.
3. Leer `orquestador/method/harness-resolution.md`.
4. Leer `orquestador/method/global-rules.md`.
5. Leer esta spec.
6. Presentar preflight.
7. Esperar `SI` antes de copiar, descargar o editar.

## Objetivo

Crear o actualizar un `.hebrinex/` operativo que materialice Hebri-AI-Harness sin copiar contexto de otro proyecto.

## Reglas

- Si el destino es el repo fuente del harness, mantener `binding_mode: source_template`.
- Si el destino es un proyecto consumidor, crear/copiar `.hebrinex/` dentro del proyecto y vincularlo como `binding_mode: bound`.
- Nunca operar un proyecto desde un harness ubicado fuera de su raiz.
- No copiar specs, ciclos, locks, approvals ni reports de otro proyecto.
- No agregar dependencias runtime al harness base.
- Mantener nombres de archivos y carpetas en ASCII.

## Estructura Canonica

La estructura canonica vive en:

```text
orquestador/harness-manifest.txt
```

`init.sh` valida esa lista. Si se agrega o elimina una pieza estructural del harness, actualizar el manifest y el changelog en la misma version.

## Flujo De Bootstrap

1. Determinar `project_root`.
2. Buscar `<project_root>/.hebrinex/`.
3. Si existe, validar `PROJECT_BINDING.yaml`.
4. Si no existe, buscar fuente local `source_template`.
5. Copiar o clonar desde `https://github.com/HebrineX/Hebri-AI-Harness`.
6. Vincular la copia con:

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

7. Asegurar que `.hebrinex/` este en `.gitignore` del proyecto consumidor.
8. Ejecutar `./.hebrinex/init.sh` con aprobacion.

## Verificacion

Esperado:

- `init.sh` retorna 0.
- Binding coherente con el proyecto.
- Manifest completo.
- `.hebrinex/` no esta trackeado por Git del proyecto consumidor.
- No hay contexto de otro proyecto dentro de specs/progress/cycles.

## Gaps Permitidos En Source Template

En `source_template` pueden existir placeholders de stack, tests y producto. En `bound`, esos placeholders deben revisarse y completar o quedar bloqueados como verificacion no definida.
