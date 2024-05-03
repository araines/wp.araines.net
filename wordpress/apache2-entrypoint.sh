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
sudo -E -u www-data wp option update siteurl "http://${CONTAINER_DNS}"
sudo -E -u www-data wp option update home "http://${CONTAINER_DNS}"

# Update WP2Static options, if environment variables are set
if [ -n "${WPSTATIC_DEST-}" ]; then
  sudo -E -u www-data wp wp2static options set deploymentURL "${WPSTATIC_DEST}"
fi
if [ -n "${WPSTATIC_REGION-}" ]; then
  sudo -E -u www-data wp db query "UPDATE wp_wp2static_addon_s3_options SET value = '$WPSTATIC_REGION' WHERE name = 's3Region';"
fi
if [ -n "${WPSTATIC_BUCKET-}" ]; then
  sudo -E -u www-data wp db query "UPDATE wp_wp2static_addon_s3_options SET value = '$WPSTATIC_BUCKET' WHERE name = 's3Bucket';"
fi

echo "Starting Apache"
exec "apache2-foreground"
