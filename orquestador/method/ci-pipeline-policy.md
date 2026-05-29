# CI Pipeline Policy

Version: 0.7.4

Esta politica evita resumir iteraciones de CI/pipeline como si hubieran sido un solo cambio.

## Cuando Aplica

Aplica cuando se documentan, corrigen o auditan:

- workflows de GitHub Actions, Azure DevOps u otra CI;
- scripts de build/test/deploy;
- cambios de pipeline en changelog o release notes;
- fallos repetidos de CI;
- capturas o logs de pipeline provistos por el operador.

## Reconstruccion

El flujo debe listar cada iteracion relevante:

- intento;
- cambio aplicado;
- evidencia del fallo o exito;
- comando/job/pipeline;
- version o commit;
- decision siguiente.

## Regla

Si el objetivo es explicar como se llego a un pipeline funcional, no se colapsan los intentos. Se documentan como secuencia.

## Bloqueos

Bloquear si:

- hay logs/capturas de CI no leidos;
- se declara pipeline funcional sin evidencia;
- se mezcla fix de CI con deploy o migracion sin version separada;
- se omite una iteracion que explica la decision final.
