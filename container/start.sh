#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

WORDPRESS_DIR="${WORDPRESS_DIR:-/home/container/wordpress}"
SERVER_DIR="${SERVER_DIR:-/home/container}"
REDIS_DIR="${REDIS_DIR:-${SERVER_DIR}/redis}"
: "${SERVER_PORT:=8080}"

: "${WORDPRESS_DB_HOST:?WORDPRESS_DB_HOST is required}"
: "${WORDPRESS_DB_PORT:=3306}"
: "${WORDPRESS_DB_NAME:?WORDPRESS_DB_NAME is required}"
: "${WORDPRESS_DB_USER:?WORDPRESS_DB_USER is required}"
: "${WORDPRESS_DB_PASSWORD:?WORDPRESS_DB_PASSWORD is required}"

: "${WORDPRESS_URL:?WORDPRESS_URL is required}"
: "${WORDPRESS_TITLE:=ACoreCMS}"
: "${WORDPRESS_ADMIN_USER:=admin}"
: "${WORDPRESS_ADMIN_PASSWORD:?WORDPRESS_ADMIN_PASSWORD is required}"
: "${WORDPRESS_ADMIN_EMAIL:=admin@example.com}"
: "${WORDPRESS_MULTISITE:=true}"
: "${WORDPRESS_MULTISITE_USE_SUBDOMAINS:=false}"

cd "$WORDPRESS_DIR"

echo "Waiting for WordPress database..."

until nc -z -w5 "$WORDPRESS_DB_HOST" "$WORDPRESS_DB_PORT"; do
    echo "Database unavailable at ${WORDPRESS_DB_HOST}:${WORDPRESS_DB_PORT}; retrying..."
    sleep 5
done

echo "Database connection available."

if [[ ! -f wp-config.php ]]; then
    echo "Creating wp-config.php..."

    wp config create \
        --dbname="$WORDPRESS_DB_NAME" \
        --dbuser="$WORDPRESS_DB_USER" \
        --dbpass="$WORDPRESS_DB_PASSWORD" \
        --dbhost="${WORDPRESS_DB_HOST}:${WORDPRESS_DB_PORT}" \
        --allow-root
fi

if ! wp core is-installed --allow-root; then
    echo "Installing WordPress..."

    if [[ "$WORDPRESS_MULTISITE" == "true" ]]; then
        multisite_args=()

        if [[ "$WORDPRESS_MULTISITE_USE_SUBDOMAINS" == "true" ]]; then
            multisite_args+=(--subdomains)
        fi

        wp core multisite-install \
            --url="$WORDPRESS_URL" \
            --title="$WORDPRESS_TITLE" \
            --admin_user="$WORDPRESS_ADMIN_USER" \
            --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
            --admin_email="$WORDPRESS_ADMIN_EMAIL" \
            "${multisite_args[@]}" \
            --allow-root
    else
        wp core install \
            --url="$WORDPRESS_URL" \
            --title="$WORDPRESS_TITLE" \
            --admin_user="$WORDPRESS_ADMIN_USER" \
            --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
            --admin_email="$WORDPRESS_ADMIN_EMAIL" \
            --allow-root
    fi
fi

echo "Ensuring ACore-CMS dependency plugins are installed..."

plugins=(
    "woocommerce|/opt/acore-cms/plugins/woocommerce-10.7.0.zip"
    "wp-graphql|/opt/acore-cms/plugins/wp-graphql-2.23.0.zip"
    "wpgraphql-acf|/opt/acore-cms/plugins/wpgraphql-acf-3.0.0.zip"
    "mycred|/opt/acore-cms/plugins/mycred-3.2.6.zip"
    "advanced-custom-fields|/opt/acore-cms/plugins/advanced-custom-fields-6.8.10.zip"
    "wordpress-importer|/opt/acore-cms/plugins/wordpress-importer-0.9.6.zip"
)

for plugin_entry in "${plugins[@]}"; do
    IFS='|' read -r plugin plugin_source <<< "$plugin_entry"

    if ! wp plugin is-installed "$plugin" --allow-root; then
        echo "Installing bundled plugin: $plugin"
        wp plugin install "$plugin_source" \
            --activate \
            --allow-root
    elif ! wp plugin is-active "$plugin" --allow-root; then
        echo "Activating plugin: $plugin"
        wp plugin activate "$plugin" --allow-root
    else
        echo "Plugin already active: $plugin"
    fi
done

if wp plugin is-installed acore-wp-plugins --allow-root; then
    if ! wp plugin is-active acore-wp-plugins --allow-root; then
        echo "Activating ACore-CMS plugin..."
        wp plugin activate acore-wp-plugins --allow-root
    else
        echo "ACore-CMS plugin already active."
    fi
else
    echo "ERROR: ACore-CMS plugin is missing."
    exit 1
fi

echo "Applying custom plugin/theme initialization..."
/usr/local/bin/pelican-custom-init.sh

echo "Configuring nginx to listen on port ${SERVER_PORT}..."
sed "s/__SERVER_PORT__/${SERVER_PORT}/g" \
    /etc/nginx/pelican.conf.template \
    > /etc/nginx/conf.d/default.conf

REDIS_PID=""
PHP_FPM_PID=""
NGINX_PID=""
SHUTTING_DOWN=0

shutdown() {
    if [[ "$SHUTTING_DOWN" -eq 1 ]]; then
        return
    fi

    SHUTTING_DOWN=1

    echo "Stopping services..."

    [[ -n "${NGINX_PID:-}" ]] && kill -TERM "$NGINX_PID" 2>/dev/null || true
    [[ -n "${PHP_FPM_PID:-}" ]] && kill -TERM "$PHP_FPM_PID" 2>/dev/null || true
    [[ -n "${REDIS_PID:-}" ]] && kill -TERM "$REDIS_PID" 2>/dev/null || true

    [[ -n "${NGINX_PID:-}" ]] && wait "$NGINX_PID" 2>/dev/null || true
    [[ -n "${PHP_FPM_PID:-}" ]] && wait "$PHP_FPM_PID" 2>/dev/null || true
    [[ -n "${REDIS_PID:-}" ]] && wait "$REDIS_PID" 2>/dev/null || true
}

handle_signal() {
    shutdown
    exit 0
}

trap handle_signal SIGTERM SIGINT SIGQUIT

echo "Starting Redis..."
redis-server \
    --bind 127.0.0.1 \
    --protected-mode yes \
    --port 6379 \
    --dir "$REDIS_DIR" \
    --dbfilename dump.rdb \
    --daemonize no &
REDIS_PID=$!

echo "Starting PHP-FPM..."
php-fpm -F &
PHP_FPM_PID=$!

echo "Starting nginx..."
nginx -g 'daemon off;' &
NGINX_PID=$!

echo "All services started."

set +e
wait -n "$REDIS_PID" "$PHP_FPM_PID" "$NGINX_PID"
EXIT_CODE=$?
set -e

if [[ "$SHUTTING_DOWN" -eq 0 ]]; then
    echo "A service exited unexpectedly with status ${EXIT_CODE}; shutting down container..."
    shutdown
    exit "$EXIT_CODE"
fi

exit 0
