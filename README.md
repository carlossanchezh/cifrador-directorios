# Cifrador de directorios

## Descripción

Conjunto de scripts en Bash para **cifrar, descifrar y cambiar claves** de los archivos de un directorio usando criptografía simétrica (AES-256-CBC con PBKDF2) y verificación de integridad mediante HMAC-SHA256.

El objetivo es proteger la confidencialidad y la integridad de un conjunto de archivos, permitiendo recuperarlos o cambiar las claves de forma segura sin exponer los datos originales.

Cada archivo se cifra de forma **individual**, de modo que un fallo en uno no compromete al resto. La integridad se garantiza en **dos niveles**: por archivo (HMAC) y de forma global (hash del conjunto).

## Arquitectura

### Modelo de seguridad

El proyecto aplica tres principios:

- **Confidencialidad** — Cifrado simétrico AES-256-CBC con derivación de clave PBKDF2 y salt aleatorio por archivo.

- **Integridad** — HMAC-SHA256 por archivo, más un hash SHA256 global del directorio protegido.

- **Borrado seguro** — Los archivos originales se eliminan con `shred`, no con `rm`.

### Funcionamiento

#### `cifrar.sh`:

Toma un directorio `<dir>` con archivos en claro, cifra cada uno con AES-256-CBC, calcula su HMAC-SHA256, genera un hash global del directorio protegido y elimina de forma segura los originales.

1. Valida el argumento (directorio existente) y normaliza la barra final (`${VAR%/}`).

2. Solicita por teclado la clave AES y la clave HMAC (sin eco, con `read -s`).

3. Crea el directorio `<dir>_protegido` con permisos `700`.

4. Para cada archivo de `<dir>`:
   - Cifra con `openssl enc -aes-256-cbc -pbkdf2 -salt`

     ```bash
     openssl enc -aes-256-cbc -pbkdf2 -salt -in "$f" -out "$OUTDIR/$base.enc" -pass pass:"$CLAVE_CIFRADA"
     ```

   - Calcula su HMAC-SHA256 `con openssl dgst -sha256 -hmac`.
  
     ```bash
     openssl dgst -sha256 -hmac "$CLAVE_HMAC" "$OUTDIR/$base.enc" | awk '{print $2}' > "$OUTDIR/$base.mac"
     ```
     
   - Aplica permisos `600` al `.enc` y al `.mac`.
  
   - Destruye el archivo original con `shred -u`.

5. Genera el hash global del directorio protegido y le aplica permisos `600`:

```bash
find "$OUTDIR" -type f ! -name 'hash_global.sha256' -exec sha256sum {} \; | sort | sha256sum > "$OUTDIR/hash_global.sha256"
```

6. Limpia las claves de memoria con `unset` y elimina el directorio original.

#### `descifrar.sh`:

Verifica la integridad global del directorio protegido, verifica el HMAC de cada archivo y los descifra a un directorio nuevo.

1. Valida el argumento y normaliza la barra final (`${VAR%/}`).

2. Solicita la clave AES y la clave HMAC.

3. Verifica el hash global del directorio protegido. Si no coincide → aborta.

4. Verifica el HMAC de cada archivo antes de descifrar ninguno. Si falla alguno → limpia el directorio de salida y aborta.

5. Descifra cada .enc al directorio `<dir>_descifrado` con la clave proporcionada. Si falla → limpia el directorio de salida y aborta.

```bash
if ! openssl enc -aes-256-cbc -pbkdf2 -d -in "$enc" -out "$OUTDIR/$base" -pass pass:"$CLAVE_CIFRADA"; then
```

6. Pregunta al usuario si desea borrar de forma segura los cifrados y sus MAC.

#### `cambiar_clave.sh`:

Permite cambiar las claves (AES y HMAC) de un directorio ya protegido sin necesidad de descifrarlo manualmente: descifra internamente con las claves antiguas y vuelve a cifrar con las nuevas.

1. Valida el argumento y normaliza la barra final (`${VAR%/}`).

2. Solicita las claves AES y HMAC antiguas y las nuevas.

3. Crea un directorio temporal `<dir>_temp_descifrado`.

4. Para cada `.enc`:

    - Verifica el HMAC con la clave HMAC antigua.
  
    - Descifra con la clave AES antigua al directorio temporal.

5. Vuelve a cifrar cada archivo temporal con las claves nuevas y regenera su `.mac`.

6. Recalcula el `hash_global.sha256` con las nuevas claves.

7. Limpia el directorio temporal y las claves de memoria con `unset`.

### Tecnologías

- Lenguaje / Intérprete de comandos: **Bash**
- Librería criptográfica: **OpenSSL**
- Algoritmo de cifrado simétrico: **AES-256-CBC**
- Código de autenticación de mensajes: **HMAC-SHA256**

## Estructura del proyecto

```plaintext
.
├── README.md              # Descripción del proyecto
├── cambiar_clave.sh       # Cambia las claves de un directorio protegido
├── cifrar.sh              # Cifra un directorio
└── descifrar.sh           # Descifra un directorio protegido
```
