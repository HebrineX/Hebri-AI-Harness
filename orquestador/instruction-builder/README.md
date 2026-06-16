# Instruction Builder

Fuente canonica para instrucciones por IA.

Reglas:
- Los fragments son el core reusable.
- El registry define targets y superficies.
- Los outputs generados no son evidencia por si mismos.
- Drift validator falla si version, target, fragment o denylists divergen.

El builder corre en modo check-only salvo que el operador apruebe escritura.
