# Modos de Operacion

El harness tiene dos modos. El modo no cambia permisos de seguridad: cambia cuanta autonomia de decision tiene el leader antes de pedir aprobacion.

## Modo Automatico

Objetivo: avanzar con fluidez cuando el operador ya aprobo un objetivo, una fase o un slice.

El leader puede hacer sin pedir aprobacion puntual:
- Leer archivos dentro del workspace permitido.
- Preparar diagnostico, plan, briefs y asignaciones.
- Decidir que rol corresponde segun el estado SDD.
- Detectar gaps, bloqueos y riesgos.
- Actualizar mentalmente la cola de trabajo antes de proponer acciones.

El leader debe pedir `SI` antes de:
- Editar o crear archivos.
- Correr comandos.
- Lanzar subagentes con escritura o verificacion.
- Llamar APIs/modelos pagados o externos.
- Crear, modificar o liberar locks.
- Cambiar estado SDD.
- Hacer git, red, deploy, instalacion de dependencias o acciones destructivas.

Formato obligatorio antes de avanzar:

```text
Modo: automatico
Accion propuesta: [accion concreta]
Alcance: [archivos/comandos/agentes]
Riesgo: bajo | medio | alto
Verificacion: [como se confirma]
Resultado esperado: [salida]
Esperando: SI del operador
```

## Modo Manual

Objetivo: control total del operador.

Reglas:
- Cada cambio requiere aprobacion previa.
- Cada comando requiere aprobacion previa.
- Cada slice se anuncia por separado.
- Cada handoff entre roles se anuncia por separado.
- Si una fase tiene 5 slices, se pide `SI` antes de cada slice.

Formato obligatorio por paso:

```text
Modo: manual
Paso: [fase/slice/tarea]
Voy a hacer: [accion]
Por que: [razon]
Tocaria: [archivos/tools/comandos]
No voy a tocar: [limites]
Criterio de salida: [verificacion]
Esperando: SI del operador
```

## Seleccion de Modo

Si el operador no define modo, usar `manual` para tareas de alto riesgo y `automatico` para exploracion o refactors documentales de bajo riesgo.

Cambiar de modo durante una sesion requiere registro en `PROGRESS.md` o en el handoff del ciclo.
