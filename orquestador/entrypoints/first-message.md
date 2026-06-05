# First Message Entrypoint

Objetivo: arrancar sin perder el contrato.

1. Resolver `.hebrinex` segun `harness-resolution.md`.
2. Leer `PROJECT_BINDING.yaml`.
3. Leer `orquestador/memory/local/session-pin.md`.
4. Leer `orquestador/memory/memory-registry.yaml`.
5. Declarar contrato de sesion.
6. Elegir perfil de contexto.
7. No ejecutar acciones con efecto sin preflight y `SI`.

Salida minima:

```text
Contrato detectado:
- Harness: si/no
- Version: 0.8.0
- Binding: ...
- Memory route: first_message
- Capas cargadas: local, project
- Rol del chat: interprete
- Leader visible: si/pendiente
- Requiere SI antes de efectos: si
```