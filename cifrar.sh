#!/bin/bash

set -e

DIRECTORIO="$1" #Se guarda primer argumento en DIR que sera el directorio

if [ -z "$DIRECTORIO" ] || [ ! -d "$DIRECTORIO" ]; then #Comprueba si no se ha pasado directorio o este no es valido
    echo "Hay que pasar un directorio correcto como argumento de programa : $0 directorio"
    exit 1

fi

read -s -p "Clave para cifrar: " CLAVE_CIFRADA #Se introduce la clave_cifrada por el usuario y se guarda en CLAVE_CIFRADA
echo 
read -s -p "Clave HMAC: " CLAVE_HMAC #Se introduce la clave_mac por el usuario y se guarda en CLAVE_HMAC
echo

DIRECTORIO="${DIRECTORIO%/}"

OUTDIR="${DIRECTORIO}_protegido" #Se crea directorio que contendra los archivos cifrados y sus macs
mkdir -p "$OUTDIR"
chmod 700 "${DIRECTORIO}_protegido" # Solo propietario puede leer/escribir/ejecutar en el directorio

for f in "$DIRECTORIO"/*; do #Se recorren todos los elementos del directorio
    [ -f "$f" ] || continue # SI el elemento no es un archivo se salta 
    base=$(basename "$f") 

    openssl enc -aes-256-cbc -pbkdf2 -salt -in "$f" -out "$OUTDIR/$base.enc" -pass pass:"$CLAVE_CIFRADA" #Se cifra cada elemento con la clave 

    openssl dgst -sha256 -hmac "$CLAVE_HMAC" "$OUTDIR/$base.enc" | awk '{print $2}' > "$OUTDIR/$base.mac" #Calcula MAC para proteger la integridad del fichero cifrado

    chmod 600 "${DIRECTORIO}_protegido"/*.mac # Solo propietario puede leer/escribir el archivo
    chmod 600 "${DIRECTORIO}_protegido"/*.enc # Solo propietario puede leer/escribir el archivo

    shred -u "$f" #Eliminar archivo original al cifrarlo

done

# Crear hash global del directorio protegido
find "$OUTDIR" -type f ! -name 'hash_global.sha256' -exec sha256sum {} \; | sort | sha256sum > "$OUTDIR/hash_global.sha256"
chmod 600 "$OUTDIR/hash_global.sha256"

echo "Completado el cifrado de $DIRECTORIO en $DIRECTORIO _protegido"

# Limpiar claves de memoria
unset CLAVE_CIFRADA
unset CLAVE_HMAC

# Eliminar directorio vacío
rm -rf "$DIRECTORIO"
