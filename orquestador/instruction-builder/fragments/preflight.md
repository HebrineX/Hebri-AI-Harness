# Fragment: Preflight

Antes de efectos: Approval ID, accion, CWD, read-set, write-set, comando/tool, red/git, riesgo, verificacion, evidencia esperada y `SI`.

El `SI` cubre el alcance agrupado, sin repetirlo por cada paso menor. Lecturas
nativas acotadas y sin secretos (incluido kernel/bootstrap) no requieren preflight,
`SI`, envelope ni Gateway. Gateway es opcional, de lectura restringida, no universal;
su contrato exacto y las restricciones reales del host siguen vigentes.
