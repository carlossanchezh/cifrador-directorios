#!/bin/bash
set -e

DIRECTORIOPROTEGIDO="$1"
if [ -z "$DIRECTORIOPROTEGIDO" ] || [ ! -d "$DIRECTORIOPROTEGIDO" ]; then
    echo "Hay que pasar un directorio correcto como argumento de programa : $0 directorio"
    exit 1
fi

read -s -p "Clave actual: " CLAVE_ANTIGUA
echo
read -s -p "Clave HMAC actual: " CLAVE_HMAC_ANTIGUA
echo
read -s -p "Nueva clave: " CLAVE_NUEVA
echo
read -s -p "Nueva clave HMAC: " CLAVE_HMAC_NUEVA
echo

DIRECTORIOPROTEGIDO="${DIRECTORIOPROTEGIDO%/}"

TEMP_DIR="${DIRECTORIOPROTEGIDO}_temp_descifrado"
mkdir -p "$TEMP_DIR"

for enc in "$DIRECTORIOPROTEGIDO"/*.enc; do
    base=$(basename "$enc" .enc)

    # Verificar MAC con HMAC antigua
    MAC_GUARDADO=$(cat "$DIRECTORIOPROTEGIDO/$base.mac")
    MAC_CALCULADO=$(openssl dgst -sha256 -hmac "$CLAVE_HMAC_ANTIGUA" "$enc" | awk '{print $2}')

    if [ "$MAC_GUARDADO" != "$MAC_CALCULADO" ]; then
        echo "Error: HMAC no coincide para $base. Archivo modificado o clave HMAC incorrecta."
        rm -rf "$TEMP_DIR"
        unset CLAVE_ANTIGUA CLAVE_HMAC_ANTIGUA CLAVE_NUEVA CLAVE_HMAC_NUEVA
	exit 1
    fi

    # Descifrar
    if ! openssl enc -aes-256-cbc -pbkdf2 -d -in "$enc" -out "$TEMP_DIR/$base" -pass pass:"$CLAVE_ANTIGUA"; then
        echo "Error: La clave de cifrado para $base es incorrecta."
        rm -rf "$TEMP_DIR"
        unset CLAVE_ANTIGUA CLAVE_HMAC_ANTIGUA CLAVE_NUEVA CLAVE_HMAC_NUEVA
	exit 1
    fi
done

for f in "$TEMP_DIR"/*; do
    base=$(basename "$f")
    openssl enc -aes-256-cbc -pbkdf2 -salt -in "$f" -out "$DIRECTORIOPROTEGIDO/$base.enc" -pass pass:"$CLAVE_NUEVA"
    openssl dgst -sha256 -hmac "$CLAVE_HMAC_NUEVA" "$DIRECTORIOPROTEGIDO/$base.enc" | awk '{print $2}' > "$DIRECTORIOPROTEGIDO/$base.mac"
done

# Crear hash global del directorio protegido tras cambiar la clave
find "$DIRECTORIOPROTEGIDO" -type f ! -name 'hash_global.sha256' -exec sha256sum {} \; | sort | sha256sum > "$DIRECTORIOPROTEGIDO/hash_global.sha256"
chmod 600 "$DIRECTORIOPROTEGIDO/hash_global.sha256"

rm -rf "$TEMP_DIR"

unset CLAVE_ANTIGUA CLAVE_HMAC_ANTIGUA CLAVE_NUEVA CLAVE_HMAC_NUEVA

echo "Se ha cambiado la clave correctamente"
