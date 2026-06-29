---
description: "Brief operativo — formato estándar para pedir trabajo a un agente"
---

Brief operativo según Vol 05 de Hebri-AI-Structure.

Objetivo:
  ${input:objetivo:Una frase verificable}

Contexto:
  Stack: ${input:stack:Lenguaje, framework, versión}
  Estado actual: ${input:estado:Qué existe hoy}
  Decisiones relevantes: ${input:decisiones:ADRs o referencias, si aplica}

Restricciones:
  ${input:restricciones:Qué NO tocar / NO cambiar — uno por línea}

Archivos relevantes:
  ${input:archivos:Rutas concretas, una por línea con "ruta — para qué sirve"}

Salida esperada:
  ${input:salida:Artefacto concreto, dónde vive}

Verificación:
  ${input:verificacion:Comando exacto que confirma el cierre}

Riesgos:
  ${input:riesgos:Qué podría romperse si se improvisa}

Nivel de autonomía: ${input:autonomia:N0 / N1 / N2 / N3 / N4 (ver Vol 08)}
