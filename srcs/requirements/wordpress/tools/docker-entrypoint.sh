#!/bin/bash
set -e

WP_ROOT="/var/www/html"

# If empty, download WordPress
if [ -z "$(ls -A $WP_ROOT 2>/dev/null)" ]; then
  echo "[wordpress] -> downloading wordpress..."
  wget -q https://wordpress.org/latest.tar.gz -O /tmp/wp.tar.gz
  tar -xzf /tmp/wp.tar.gz -C /tmp
  mv /tmp/wordpress/* $WP_ROOT
  rm -rf /tmp/wp.tar.gz /tmp/wordpress
  chown -R www-data:www-data $WP_ROOT
fi

# Read DB password from secret file if provided
if [ -f /run/secrets/db_password.txt ]; then
  DB_PASS=$(cat /run/secrets/db_password.txt)
fi

# Create wp-config.php if not exists
if [ ! -f "$WP_ROOT/wp-config.php" ]; then
  cp $WP_ROOT/wp-config-sample.php $WP_ROOT/wp-config.php
  sed -i "s/database_name_here/${WORDPRESS_DB_NAME:-wordpress}/" $WP_ROOT/wp-config.php
  sed -i "s/username_here/${WORDPRESS_DB_USER:-wp_user}/" $WP_ROOT/wp-config.php
  sed -i "s/password_here/${DB_PASS:-}/" $WP_ROOT/wp-config.php
  # allow external DB host
  sed -i "s/localhost/${WORDPRESS_DB_HOST}/" $WP_ROOT/wp-config.php
  chown www-data:www-data $WP_ROOT/wp-config.php
fi

# If WP admin password secret exists, optionally create admin via WP-CLI (not installed)
# We leave WP admin creation to the first visit / manual install or you can add WP-CLI script.

exec "$@"
