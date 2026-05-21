# Secret Denylist

## Bloqueado por defecto

No leer, imprimir, resumir, copiar ni enviar:

- `.env`, `.env.*`
- `*.pem`, `*.key`, `*.pfx`, `*.p12`, `*.crt`
- archivos con `token`, `secret`, `password`, `credential`, `apikey`, `private`
- dumps de bases de datos
- backups con datos reales
- logs con datos personales o credenciales
- configuraciones productivas sensibles

## Si el operador pide revisar uno

1. Confirmar objetivo exacto.
2. Pedir aprobacion explicita para esa ruta.
3. Preferir revisar estructura/nombres, no valores.
4. No repetir secretos en la respuesta.
5. Registrar evidencia sanitizada.
