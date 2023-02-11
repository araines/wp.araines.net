#!/bin/bash
set -euo pipefail

# Original image entrypoint first
#echo $@
#docker-entrypoint.sh $@

# Get IP address of ECS container and update DNS appropriately
# TODO
CONTAINER_DNS="localhost:8000"
SITE_NAME="Andy Raines"
WORDPRESS_ADMIN_EMAIL="andrew.raines@gmail.com"
WORDPRESS_ADMIN_USER="araines"
WORDPRESS_ADMIN_PASSWORD="changeme"

# Install WordPress (if not installed)
if ! sudo -E -u www-data wp core is-installed; then
  echo "WordPress not installed: installing WordPress"
  sudo -E -u www-data wp core install --url="http://${CONTAINER_DNS}" --title="${SITE_NAME}" --admin_user="${WORDPRESS_ADMIN_USER}" --admin_password="${WORDPRESS_ADMIN_PASSWORD}" --admin_email="${WORDPRESS_ADMIN_EMAIL}" --skip-email
fi

chown www-data:www-data /root

# Install WP2Static & s3 plugin (if not installed)
if ! sudo -E -u www-data wp plugin is-installed wp2static; then
  echo "WP2Static not installed: installing WP2Static"
  sudo -E -u www-data composer install -n --no-dev --working-dir /tmp/
  sudo -E -u www-data composer build wp2static --working-dir /tmp/vendor/leonstafford/wp2static
  sudo -E -u www-data wp plugin install --activate ~/Downloads/wp2static.zip  
  if ! sudo -E -u www-data wp plugin is-installed wp2static-addon-s3; then
    echo "WP2Static-S3-Plugin not installed: installing WP2Static-S3-Plugin"
    sudo -E -u www-data composer build wp2static-addon-s3 --working-dir /tmp/vendor/leonstafford/wp2static-addon-s3
    sudo -E -u www-data wp plugin install --activate ~/Downloads/wp2static-addon-s3.zip
  fi
fi

# Update WordPress options with IP of running container
# TODO


echo "Starting Apache"
exec "apache2-foreground"
