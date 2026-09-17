#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/home/container}"
WORDPRESS_DIR="${WORDPRESS_DIR:-${SERVER_DIR}/wordpress}"
CONF_DIR="${CONF_DIR:-${SERVER_DIR}/conf}"
LOG_DIR="${LOG_DIR:-${SERVER_DIR}/logs}"
REDIS_DIR="${REDIS_DIR:-${SERVER_DIR}/redis}"

ACORE_PLUGIN_SOURCE="/opt/acore-cms/acore-wp-plugin"
ACORE_PLUGIN_DEST="${WORDPRESS_DIR}/wp-content/plugins/acore-wp-plugins"

mkdir -p \
    "$WORDPRESS_DIR" \
    "$CONF_DIR/init" \
    "$LOG_DIR" \
    "$REDIS_DIR"

# Seed WordPress core files into persistent storage on first boot.
if [[ ! -f "$WORDPRESS_DIR/wp-settings.php" ]]; then
    echo "Initializing persistent WordPress files..."
    cp -a /usr/src/wordpress/. "$WORDPRESS_DIR"/
fi

# Seed the bundled ACore-CMS plugin into the persistent WordPress install.
echo "Synchronizing bundled ACore-CMS plugin..."

rm -rf "$ACORE_PLUGIN_DEST"

cp -a "$ACORE_PLUGIN_SOURCE" "$ACORE_PLUGIN_DEST"

echo "Runtime identity:"
id

exec "$@"
