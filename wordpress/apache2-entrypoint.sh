#!/bin/bash
set -euo pipefail

# Get IP address of ECS container and update DNS appropriately if running on ECS
if [ -z ${ECS_CONTAINER_METADATA_URI_V4-} ]; then
  echo "Detected running in local mode"
else
  echo "Detected running in ECS"

  PRIVATE_IP=$(curl ${ECS_CONTAINER_METADATA_URI_V4}/task | jq -r '.Containers[0].Networks[0].IPv4Addresses[0]') || true
  echo "Private IP address: $PRIVATE_IP"

  PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --filters Name=addresses.private-ip-address,Values=$PRIVATE_IP \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --region $WPSTATIC_REGION \
    --output=text) || true
  echo "Public IP address: $PUBLIC_IP"

  UPDATE_RESP=$(aws route53 change-resource-record-sets \
    --hosted-zone-id ${CONTAINER_DNS_ZONE} \
    --change-batch "{\"Comment\": \"Update wordpress endpoint with public IP\", \"Changes\": [{\"Action\": \"UPSERT\", \"ResourceRecordSet\": {\"Name\": \"${CONTAINER_DNS}\", \"Type\": \"A\", \"TTL\": "60", \"ResourceRecords\": [{\"Value\": \"${PUBLIC_IP}\"}]}}]}" \
    --region $WPSTATIC_REGION)
  echo "Route53 response: $UPDATE_RESP"
fi

# Install WordPress (if not installed)
if ! sudo -E -u www-data wp core is-installed; then
  echo "WordPress not installed: installing WordPress"
  sudo -E -u www-data wp core install --url="http://${CONTAINER_DNS}" --title="${WORDPRESS_SITE_NAME}" --admin_user="${WORDPRESS_ADMIN_USER}" --admin_password="${WORDPRESS_ADMIN_PASSWORD}" --admin_email="${WORDPRESS_ADMIN_EMAIL}" --skip-email

  # UK locale settings
  sudo -E -u www-data wp language core install --activate en_GB
  sudo -E -u www-data wp option update timezone_string "Europe/London"
  sudo -E -u www-data wp option update date_format "j F Y"
  sudo -E -u www-data wp option update time_format "H:i"

  # Disable pingbacks and commenting (won't work on static site)
  sudo -E -u www-data wp option update default_pingback_flag 0
  sudo -E -u www-data wp option update default_ping_status 0
  sudo -E -u www-data wp option update default_comment_status 0

  # Postname URL structures for permalinks (better for SEO)
  sudo -E -u www-data wp option update permalink_structure "/%postname%/"

  # Remove default plugins
  sudo -E -u www-data wp plugin delete akismet hello

  # Remove unwanted default themes
  sudo -E -u www-data wp theme delete twentytwentytwo twentytwentythree
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

# Update WP2Static options, if environment variables are set
if [ -n "${WPSTATIC_DEST-}" ]; then
  sudo -E -u www-data wp wp2static options set deploymentURL "${WPSTATIC_DEST}"
fi
if [ -n "${WPSTATIC_REGION-}" ] && [ -n "${WPSTATIC_BUCKET-}" ]; then
  sudo -E -u www-data wp db query "UPDATE wp_wp2static_addon_s3_options SET value = '$WPSTATIC_REGION' WHERE name = 's3Region'"
  sudo -E -u www-data wp db query "UPDATE wp_wp2static_addon_s3_options SET value = '$WPSTATIC_BUCKET' WHERE name = 's3Bucket'"
  sudo -E -u www-data wp db query "UPDATE wp_wp2static_addon_s3_options SET value = 'private' WHERE name = 's3ObjectACL'"
  sudo -E -u www-data wp db query "UPDATE wp_wp2static_addons SET enabled = 1 WHERE slug = 'wp2static-addon-s3'"
fi

# Install UpdraftPlus
if ! sudo -E -u www-data wp plugin is-installed updraftplus; then
  echo "UpdraftPlus not installed: installing UpdraftPlus"
  sudo -E -u www-data wp plugin install --activate updraftplus
fi

# Install Yoast SEO
if ! sudo -E -u www-data wp plugin is-installed wordpress-seo; then
  echo "Yoast SEO not installed: installing Yoast SEO"
  sudo -E -u www-data wp plugin install --activate wordpress-seo
fi

# Install Syntax Highlighting Code Block
if ! sudo -E -u www-data wp plugin is-installed syntax-highlighting-code-block; then
  echo "Syntax Highlighting Code Block not installed: installing Syntax Highlighting Code Block"
  sudo -E -u www-data wp plugin install --activate syntax-highlighting-code-block
  sudo -E -u www-data wp option update syntax_highlighting --format=json \
    '{"theme_name":"a11y-dark","highlighted_line_background_color":"#4a4a4a"}'
fi

# Install Safe SVG (for site logo)
if ! sudo -E -u www-data wp plugin is-installed safe-svg; then
  echo "Safe SVG not installed: installing Safe SVG"
  sudo -E -u www-data wp plugin install --activate safe-svg
fi

# Install EWWW Image Optimizer (webp)
if ! sudo -E -u www-data wp plugin is-installed ewww-image-optimizer; then
  echo "EWWW not installed: installing EWWW"
  sudo -E -u www-data wp plugin install --activate ewww-image-optimizer
  sudo -E -u www-data wp option update ewww_image_optimizer_backup_files local
  sudo -E -u www-data wp option update ewww_image_optimizer_picture_webp 1
  sudo -E -u www-data wp option update ewww_image_optimizer_goal_site_speed 1
  sudo -E -u www-data wp option update ewww_image_optimizer_dismiss_exec_notice 1
  sudo -E -u www-data wp option update ewww_image_optimizer_webp 1
  sudo -E -u www-data wp option update ewww_image_optimizer_maxmediawidth 2560
  sudo -E -u www-data wp option update ewww_image_optimizer_maxmediaheight 2560
  sudo -E -u www-data wp option update ewww_image_optimizer_wizard_complete 1
  sudo -E -u www-data wp option update ewww_image_optimizer_hide_newsletter_signup 1
fi

# Update WordPress options with IP of running container
sudo -E -u www-data wp option update siteurl "http://${CONTAINER_DNS}"
sudo -E -u www-data wp option update home "http://${CONTAINER_DNS}"

echo "Starting Apache"
exec "apache2-foreground"
