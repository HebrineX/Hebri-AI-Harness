# Permisos y Ownership

## Principio

El ownership define escritura autorizada. La lectura tambien tiene limites cuando puede exponer secretos, datos personales o carpetas fuera del proyecto.

## Zonas Permitidas

| Zona | Lectura | Escritura | Notas |
|---|---|---|---|
| Workspace del proyecto | Permitida | Solo con ownership | Respetar modo automatico/manual |
| `.hebrinex/` | Permitida | Solo archivos de harness autorizados | No reescribir metodologia sin registro |
| `.hebrinex/orquestador/sdd/progress/` | Permitida | Append-only salvo registry/locks/gates propios | Memoria operativa |

## Nunca Tocar Sin Aprobacion Humana

- `.env`, secretos, llaves, certificados, tokens, archivos de credenciales.
- Carpetas fuera del workspace y fuera de `.hebrinex`.
- Bases de datos, volumenes Docker, backups, migraciones destructivas.
- Configuracion global del sistema o del usuario.
- Git push, force push, tags remotos, releases, deploys.
- Operaciones masivas: borrar, mover, sobrescribir o formatear arboles completos.

## Categorias de Archivo

| Categoria | Regla |
|---|---|
| `exclusive` | Un solo agente con lock activo puede escribir. |
| `shared-read` | Muchos agentes pueden leer; nadie escribe. |
| `append-only` | Varios pueden agregar entradas sin editar contenido previo. |
| `generated` | Solo se modifica con comando generador registrado. |
| `forbidden` | Requiere aprobacion humana explicita. |

## Reglas de Ownership

- Nunca delegar de forma abstracta: prohibido "arregla lo que veas".
- Siempre incluir `Archivos relevantes` para lectura y `Ownership exclusivo` para escritura.
- En tareas paralelas, los ownerships no pueden solaparse.
- Si dos agentes necesitan el mismo archivo, el leader serializa.
- Si un implementer necesita salir del ownership, debe parar y escalar.

## Fallos Parciales

Si un comando falla despues de modificar estado:
1. Reportar error exacto.
2. Listar archivos tocados.
3. Informar si hay lock activo.
4. Informar estado git/worktree si aplica.
5. Proponer recuperacion.
6. No revertir automaticamente salvo instruccion humana explicita.

## Artefactos P0 de Permisos

Antes de usar tools, comandos, red o git, consultar:

- `tool-policy.yaml` para decision `allow | ask | deny` por rol y clase.
- `command-taxonomy.md` para clasificar comandos.
- `write-set-policy.md` para declarar y verificar escritura.
- `secret-denylist.md` para archivos sensibles bloqueados por defecto.

Si una accion no esta clasificada, se trata como `unknown` y requiere preflight + `SI`.
