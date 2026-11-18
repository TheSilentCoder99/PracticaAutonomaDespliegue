#!/bin/bash

# Qué hace: instala Apache (servidor web), PHP (lenguaje) y MySQL (base de datos), más las extensiones de PHP que WordPress necesitará después. Es la base de todo lo demás: si falla, nada de lo siguiente funciona.

set -ex

# Comprobamos que el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ejecutarse con sudo"
  exit 1
fi

# Evitamos que apt haga preguntas interactivas
export DEBIAN_FRONTEND=noninteractive

# Actualizamos la lista de paquetes
apt update

# Instalamos Apache, MySQL, PHP y las extensiones que necesita WordPress
apt install -y apache2 mysql-server php libapache2-mod-php php-mysql \
  php-curl php-gd php-mbstring php-xml php-zip php-intl unzip gettext-base

# Habilitamos el módulo rewrite de Apache (enlaces permanentes y redirecciones)
a2enmod rewrite

# Reiniciamos Apache para aplicar los cambios
systemctl restart apache2