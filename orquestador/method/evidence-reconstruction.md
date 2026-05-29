# Evidence Reconstruction

Este metodo regula artefactos que resumen trabajo pasado. El objetivo es que el agente no invente continuidad, no dependa de memoria conversacional y no pida al operador datos que ya existen en el proyecto.

## Artefactos Derivados

Un artefacto derivado es cualquier archivo que resume, versiona o interpreta actividad previa:

- changelog
- release notes
- README de version
- reportes finales
- roadmap consolidado
- documentacion de deploy, migracion o CI
- auditorias de cumplimiento
- resumen ejecutivo de avance

## Regla Central

Primero evidencia, despues narrativa.

El agente debe reconstruir hechos desde fuentes locales y separar lo observado de lo inferido antes de escribir o cerrar.

## Flujo Minimo

1. Declarar scope del artefacto derivado.
2. Declarar read-set esperado.
3. Leer fuentes locales disponibles.
4. Crear matriz de eventos.
5. Marcar gaps, contradicciones y fuentes ausentes.
6. Proponer estructura del artefacto.
7. Hacer preflight de escritura.
8. Esperar `SI` si la accion tiene efecto.
9. Escribir.
10. Validar que la salida cubre la matriz.

## Fuentes Tipicas

- `PROGRESS.md`
- `CHANGELOG.md`
- `state.yaml`
- `registry.yaml`
- `registry.md`
- gate logs
- final reports
- audit trails
- commits locales
- branches/tags locales
- logs provistos por el operador
- capturas o reportes externos referenciados

## Salida Minima de Analisis

```text
Hechos observados:
- ...

Inferencias:
- ...

Contradicciones:
- ...

Gaps:
- ...

Decision propuesta:
- ...
```

## Bloqueos

El flujo queda bloqueado si:

- una fuente local critica existe pero no se leyo;
- `PROGRESS.md`, registry y git cuentan historias incompatibles y no se marca la contradiccion;
- se quiere escribir una conclusion sin evidencia;
- faltan datos para versionar y no se propone version sintetica marcada como tal;
- el agente intenta resolver una duda historica preguntando primero al operador sin investigar fuentes disponibles.

## Responsabilidad por Rol

- `leader`: define scope, read-set y gate.
- `auditor(profile: release)`: detecta gaps, contradicciones y eventos sin mapear.
- `reporter`: convierte el resultado en salida clara sin cambiar veredictos.
- `implementer/docs_writer`: solo escribe despues de matriz aprobada o preflight aceptado.
