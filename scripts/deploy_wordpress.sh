#!/bin/bash

set -ex

# Nos situamos en la carpeta del script para que las rutas relativas funcionen
cd "$(dirname "$0")"

# Importamos las variables de entorno
source .env

# Comprobamos que las variables necesarias tienen valor
: "${LETS_ENCRYPT_DOMAIN:?Asigne un valor a LETS_ENCRYPT_DOMAIN en .env}"
: "${DB_NAME:?Asigne un valor a DB_NAME en .env}"
: "${DB_USER:?Asigne un valor a DB_USER en .env}"
: "${DB_PASSWORD:?Asigne un valor a DB_PASSWORD en .env}"
: "${DB_HOST:?Asigne un valor a DB_HOST en .env}"
: "${IP_CLIENTE_MYSQL:?Asigne un valor a IP_CLIENTE_MYSQL en .env}"
: "${WORDPRESS_TITLE:?Asigne un valor a WORDPRESS_TITLE en .env}"
: "${WORDPRESS_ADMIN_USER:?Asigne un valor a WORDPRESS_ADMIN_USER en .env}"
: "${WORDPRESS_ADMIN_PASSWORD:?Asigne un valor a WORDPRESS_ADMIN_PASSWORD en .env}"
: "${ADMIN_EMAIL:?Asigne un valor a ADMIN_EMAIL en .env}"

# Eliminamos descargas previas de WP-CLI
rm -f /tmp/wp-cli.phar

# Descargamos WP-CLI
wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P /tmp

# Le asignamos permisos de ejecución y lo movemos al PATH
chmod +x /tmp/wp-cli.phar
mv /tmp/wp-cli.phar /usr/local/bin/wp

# Eliminamos instalaciones previas de WordPress
rm -rf /var/www/html/*

# Descargamos WordPress en español
wp core download --locale=en_US --path=/var/www/html --allow-root

# Creamos la base de datos de WordPress
mysql -u root -e "DROP DATABASE IF EXISTS $DB_NAME"
mysql -u root -e "CREATE DATABASE $DB_NAME"

# Creamos el usuario de la base de datos y le damos privilegios
mysql -u root -e "DROP USER IF EXISTS '$DB_USER'@'$IP_CLIENTE_MYSQL'"
mysql -u root -e "CREATE USER '$DB_USER'@'$IP_CLIENTE_MYSQL' IDENTIFIED BY '$DB_PASSWORD'"
mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'$IP_CLIENTE_MYSQL'"

# Creamos el archivo wp-config.php
wp config create \
  --dbname="$DB_NAME" \
  --dbuser="$DB_USER" \
  --dbpass="$DB_PASSWORD" \
  --dbhost="$DB_HOST" \
  --path=/var/www/html \
  --allow-root

# Instalamos WordPress
wp core install \
  --url="https://$LETS_ENCRYPT_DOMAIN" \
  --title="$WORDPRESS_TITLE" \
  --admin_user="$WORDPRESS_ADMIN_USER" \
  --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
  --admin_email="$ADMIN_EMAIL" \
  --skip-email \
  --path=/var/www/html \
  --allow-root

# Configuramos los enlaces permanentes y escribimos el .htaccess
wp rewrite structure '/%postname%/' --hard \
  --path=/var/www/html \
  --allow-root

  # Escribimos el .htaccess de WordPress (WP-CLI no puede hacerlo desde la terminal)
cat > /var/www/html/.htaccess <<'EOF'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF

# Instalamos el plugin WPS Hide Login y fijamos la URL de login
wp plugin install wps-hide-login --activate \
  --path=/var/www/html \
  --allow-root
wp option update whl_page admin-wp --path=/var/www/html --allow-root

# Asignamos el propietario y el grupo de /var/www/html a www-data
chown -R www-data:www-data /var/www/html