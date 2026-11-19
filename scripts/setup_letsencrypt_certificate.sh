#!/bin/bash
set -ex

# Nos situamos en la carpeta del script para que las rutas relativas funcionen
cd "$(dirname "$0")"

# Comprobamos que el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ejecutarse con sudo"
  exit 1
fi

# Exportamos automáticamente las variables cargadas desde .env para que envsubst las vea
set -a
source .env
set +a

# Comprobamos que las variables obligatorias tienen valor
: "${LETS_ENCRYPT_DOMAIN:?Asigne un valor a LETS_ENCRYPT_DOMAIN en .env}"
: "${LETS_ENCRYPT_EMAIL:?Asigne un valor a LETS_ENCRYPT_EMAIL en .env}"

# Eliminamos si existiese alguna instalación previa de certbot con apt
apt remove -y certbot || true

# Instalamos el cliente de Certbot con snap y creamos el enlace del comando
snap install --classic certbot
ln -sf /snap/bin/certbot /usr/bin/certbot

# Deshabilitamos los virtual hosts por defecto para evitar conflictos
a2dissite 000-default.conf || true
a2dissite default-ssl.conf || true

# Generamos el VirtualHost del dominio a partir de la plantilla y lo activamos
envsubst '${LETS_ENCRYPT_DOMAIN} ${LETS_ENCRYPT_EMAIL}' < ../conf/virtualhost.conf.template > "/etc/apache2/sites-available/${LETS_ENCRYPT_DOMAIN}.conf"
a2ensite "${LETS_ENCRYPT_DOMAIN}.conf"

# Comprobamos configuración y recargamos Apache antes de llamar a Certbot
apache2ctl configtest
systemctl reload apache2

# Solicitamos el certificado y configuramos HTTPS + redirección HTTP -> HTTPS
certbot --apache \
  -m "$LETS_ENCRYPT_EMAIL" \
  --agree-tos \
  --no-eff-email \
  -d "$LETS_ENCRYPT_DOMAIN" \
  --non-interactive \
  --redirect