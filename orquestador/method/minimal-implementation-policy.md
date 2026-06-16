# Minimal Implementation Policy

Version: 0.8.7

Esta politica evita que el agente construya mas de lo necesario. Se ejecuta antes de cualquier implementacion o cambio con escritura mediante `auditor(profile: detractor_senior)`.

## Escalera Senior

Antes de escribir, responder en orden:

1. Hace falta construir esto?
2. Lo resuelve el lenguaje o stdlib?
3. Lo resuelve la plataforma, framework o motor nativo?
4. Lo resuelve una dependencia ya instalada?
5. Puede resolverse con menos archivos/codigo sin perder claridad?
6. Solo entonces: escribir la solucion minima correcta.

## No se simplifica

Nunca reducir codigo a costa de:

- validacion en bordes de confianza;
- manejo de errores que evita perdida de datos;
- seguridad;
- accesibilidad;
- trazabilidad SDD;
- evidencia verificable;
- contrato del harness;
- aprobacion humana.

## Gate obligatorio

`G3A_detractor_senior_pre_implementation` debe estar en `pass` antes de `G4_execution_complete` para cambios con escritura.

## Bypass excepcional

Solo con aprobacion explicita del operador:

```text
Bypass detractor_senior:
- Motivo:
- Riesgo:
- Aprobado por:
- Expira en:
```

El bypass no permite saltar seguridad, datos, accesibilidad, contrato ni evidencia.