#!/bin/bash

set -e 

DIRECTORIOPROTEGIDO="$1" #Guarda en DIRECTORIOPROTEGIDO el directorio cifrado pasado como argumento
if [ -z "$DIRECTORIOPROTEGIDO" ] || [ ! -d "$DIRECTORIOPROTEGIDO" ]; then #Se comprueba que se haya pasado un directorio y que este sea corrcto
    echo "Hay que pasar un directorio correcto como argumento de programa : $0 directorio"
    exit 1
fi

read -s -p "Clave para descifrar (ha de ser la misma con la que se cifro): " CLAVE_CIFRADA #Se introduce la clave_cifrada por el usuario y se guarda en CLAVE_CIFRADA
echo
read -s -p "Clave HMAC: " CLAVE_HMAC #Se introduce la clave_mac por el usuario y se guarda en CLAVE_HMAC
echo

DIRECTORIOPROTEGIDO="${DIRECTORIOPROTEGIDO%/}"

# Comprobar integridad global
if [ -f "$DIRECTORIOPROTEGIDO/hash_global.sha256" ]; then
    CHECK_CALCULADO=$(find "$DIRECTORIOPROTEGIDO" -type f ! -name 'hash_global.sha256' -exec sha256sum {} \; | sort | sha256sum)
    CHECK_GUARDADO=$(cat "$DIRECTORIOPROTEGIDO/hash_global.sha256")

    if [ "$CHECK_CALCULADO" != "$CHECK_GUARDADO" ]; then
        echo "Error: El directorio protegido ha sido modificado (archivos .enc o .mac alterados)."
        exit 1
    fi
fi

OUTDIR="${DIRECTORIOPROTEGIDO}_descifrado" #Se crea directorio donde se guaran los archivos descifrados
mkdir -p "$OUTDIR"

for enc in "$DIRECTORIOPROTEGIDO"/*.enc; do #Se recorren todos los archivos cifrados
    [ -f "$enc" ] || continue #Si el elemnto no es un archivo cifrado se salta 
    base=$(basename "$enc" .enc) #Nombre del archivo sin .enc

    MAC_GUARDADO=$(cat "$DIRECTORIOPROTEGIDO/$base.mac") #Se recupera el mac guardado del archivo
    MAC_CALCULADO=$(openssl dgst -sha256 -hmac "$CLAVE_HMAC" "$enc" | awk '{print $2}') #Se recalcula el mac
    if [ "$MAC_GUARDADO" != "$MAC_CALCULADO" ]; then #Se comprueba si estos son iguales
        echo "El archivo $base fue modificado, hay un problema en cuanto a su integridad o su clave HMAC introducida es incorrecta"
        rm -rf "$OUTDIR"
	unset CLAVE_CIFRADA CLAVE_HMAC
	 exit 1
    fi

    if ! openssl enc -aes-256-cbc -pbkdf2 -d -in "$enc" -out "$OUTDIR/$base" -pass pass:"$CLAVE_CIFRADA"; then #Trata de descifrar con la clave pasada por el usuario
	rm -rf "$OUTDIR"
    	unset CLAVE_CIFRADA CLAVE_HMAC
	echo "La clave para descifrar es incorrecta"
        exit 1
    fi

    echo "$base Descifrado"

done

# Limpiar claves de memoria
unset CLAVE_CIFRADA
unset CLAVE_HMAC

# Preguntar al usuario si desea eliminar los cifrados de forma segura
read -p "¿Desea eliminar los archivos cifrados y sus MAC? (s/n): " RESPUESTA
if [ "$RESPUESTA" = "s" ]; then
    for f in "$DIRECTORIOPROTEGIDO"/*.{enc,mac}; do
        [ -f "$f" ] || continue
        shred -u "$f"
    done
    rm -rf "$DIRECTORIOPROTEGIDO"
    echo "Archivos eliminados de forma segura."
    
fi
