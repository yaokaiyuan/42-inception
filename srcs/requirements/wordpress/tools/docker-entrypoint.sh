#!/bin/bash

WP_ROOT="/var/www/html"

# Download WordPress if not already present (check for index.php)
if [ ! -f "$WP_ROOT/index.php" ]; then
  echo "[wordpress] -> downloading wordpress..."
  # Remove any existing files that might interfere
  rm -rf $WP_ROOT/*
  wget -q https://wordpress.org/latest.tar.gz -O /tmp/wp.tar.gz
  tar -xzf /tmp/wp.tar.gz -C /tmp
  mv /tmp/wordpress/* $WP_ROOT
  rm -rf /tmp/wp.tar.gz /tmp/wordpress
  chown -R www-data:www-data $WP_ROOT
  echo "[wordpress] -> WordPress downloaded successfully"
fi

# Read DB password from secret file if provided
if [ -f /run/secrets/db_password ]; then
  DB_PASS=$(cat /run/secrets/db_password)
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

# Configure PHP-FPM to listen on TCP port 9000
sed -i 's/listen = .*/listen = 9000/' /etc/php/8.2/fpm/pool.d/www.conf

# Start WordPress installation in background
(
  # Wait for DB to be ready
  echo "[wordpress] -> waiting for mariadb..."
  sleep 10
  
  # Check if WP is installed
  if ! wp core is-installed --allow-root --path=$WP_ROOT 2>/dev/null; then
    echo "[wordpress] -> installing wordpress..."
    
    # Read passwords
    if [ -f /run/secrets/wp_admin_password ]; then
      ADMIN_PASS=$(cat /run/secrets/wp_admin_password)
    else
      ADMIN_PASS="admin"
    fi
    
    if [ -f /run/secrets/wp_user_password ]; then
      USER_PASS=$(cat /run/secrets/wp_user_password)
    else
      USER_PASS="user"
    fi

    # Install WP
    wp core install --url="https://$DOMAIN_NAME" \
      --title="Inception" \
      --admin_user="$WP_ADMIN_USER" \
      --admin_password="$ADMIN_PASS" \
      --admin_email="$WP_ADMIN_EMAIL" \
      --allow-root --path=$WP_ROOT 2>&1 && echo "[wordpress] -> WordPress installed successfully!" || echo "[wordpress] -> WordPress installation failed, will retry on next restart"

    # Create second user
    wp user create "$WP_USER" "$WP_EMAIL" \
      --user_pass="$USER_PASS" \
      --role=author \
      --allow-root --path=$WP_ROOT 2>&1 && echo "[wordpress] -> Second user created!" || echo "[wordpress] -> User creation failed"
  else
    echo "[wordpress] -> WordPress already installed"
  fi
) &

exec "$@"
