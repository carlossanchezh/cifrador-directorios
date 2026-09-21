# Instrucciones de instalación y ejecución

## Requisitos

- **Bash** 4.0 o superior

- **OpenSSL** instalado

- **Linux** o **WSL** (Windows Subsystem for Linux)

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/carlossanchezh/cifrador-directorios.git
```

### 2. Dar permisos de ejecución a los scripts

```bash
chmod +x cifrar.sh descifrar.sh cambiar_clave.sh
```

## Ejecución

### Cifrar un directorio

```bash
./cifrar.sh <directorio>
```

Se crea `<directorio>_protegido/` con los archivos cifrados, sus MAC y el hash global. El directorio original se elimina de forma segura.

>Guarda las claves en un lugar seguro: si las pierdes, los datos son irrecuperables.

>No uses `.` ni `..` como argumento de `cifrar.sh`, ya que el directorio original se elimina al terminar.

### Descifrar un directorio protegido

```bash
./descifrar.sh <directorio>_protegido
```

Se crea `<directorio>_protegido_descifrado/` con los archivos originales. Al terminar, el script pregunta si se desean borrar los cifrados.

### Cambiar las claves de un directorio protegido

```bash
./cambiar_clave.sh <directorio>_protegido
```

Se solicita la clave actual, la HMAC actual, la nueva clave y la nueva HMAC. Los archivos se descifran y se vuelven a cifrar con las nuevas claves sin perder datos.
