#!/bin/bash
set -e

# If database dir is empty, initialize
DATADIR="/var/lib/mysql"
INIT_FLAG="$DATADIR/.initialized"
mkdir -p /var/run/mysqld
chown -R mysql:mysql /var/run/mysqld
chown -R mysql:mysql "$DATADIR"

# Configure MariaDB to listen on all interfaces
sed -i 's/bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

if [ ! -d "$DATADIR/mysql" ]; then
  echo "[mariadb] -> initializing database..."
  mariadb-install-db --user=mysql --datadir="$DATADIR" --skip-test-db
fi

# Only run setup if this is the first time
if [ ! -f "$INIT_FLAG" ]; then
  echo "[mariadb] -> first time setup, configuring database..."
  
  # create a temp config to start the server in background for setup
  mysqld_safe --datadir="$DATADIR" &
  MYSQL_PID=$!
  # wait for mysqld to start (simple wait loop)
  for i in {1..30}; do
    mysqladmin ping &>/dev/null && break
    sleep 1
  done

  # Read secrets if present
  if [ -f /run/secrets/db_root_password ]; then
    ROOT_PASS=$(cat /run/secrets/db_root_password)
  else
    ROOT_PASS=""
  fi

  if [ -f /run/secrets/db_password ]; then
    WP_DB_PASS=$(cat /run/secrets/db_password)
  else
    WP_DB_PASS=""
  fi

  # Create DB and users if not exists
  mysql -u root <<-EOSQL
    CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE:-wordpress} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS '${MYSQL_USER:-wp_user}'@'%' IDENTIFIED BY '${WP_DB_PASS}';
    GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE:-wordpress}.* TO '${MYSQL_USER:-wp_user}'@'%';
    FLUSH PRIVILEGES;
EOSQL

  # If root password provided, set it
  if [ -n "$ROOT_PASS" ]; then
    mysql -u root <<-EOSQL
      ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';
      FLUSH PRIVILEGES;
EOSQL
  fi

  # Create flag file to mark initialization complete
  touch "$INIT_FLAG"

  # kill the background server and exec final one in foreground (CMD will run it)
  kill $MYSQL_PID || true
  wait $MYSQL_PID 2>/dev/null || true
else
  echo "[mariadb] -> database already initialized, skipping setup"
fi

exec "$@"
