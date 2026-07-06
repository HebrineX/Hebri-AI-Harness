---
name: agente-inseguro
description: Fixture negativo - subagente nativo que declara una tool de escritura. check-adapter-drift.ps1 DEBE detectarlo como inseguro.
tools: Read, Grep, Glob, Write
---

Este fixture no es un agente real: existe para el test negativo del
check de tools read-only de los subagentes nativos.
