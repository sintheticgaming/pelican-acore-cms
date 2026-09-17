#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

WORDPRESS_DIR="${WORDPRESS_DIR:-/home/container/wordpress}"
CONF_DIR="${CONF_DIR:-/home/container/conf}"
EXTERNAL_CONFIG_DIR="${CONF_DIR}/init"
STATE_DIR="${CONF_DIR}/state"

plugins_install=()
themes_install=()
plugins_activate_only=()
themes_activate_only=()

mkdir -p "$EXTERNAL_CONFIG_DIR" "$STATE_DIR"

if [[ -d "$EXTERNAL_CONFIG_DIR" ]]; then
    echo "Loading external ACore-CMS initialization configs..."

    shopt -s nullglob

    for config_file in "$EXTERNAL_CONFIG_DIR"/*.conf; do
        echo "Loading configuration: $config_file"
        # shellcheck source=/dev/null
        source "$config_file"
    done

    shopt -u nullglob
fi

cd "$WORDPRESS_DIR"

for plugin in "${plugins_install[@]}"; do
    IFS='|' read -r plugin_name plugin_slug plugin_source <<< "$plugin"

    if [[ -z "${plugin_source:-}" ]]; then
        plugin_source="$plugin_slug"
    fi

    if ! wp plugin is-installed "$plugin_slug" --allow-root; then
        echo "Installing custom plugin: ${plugin_name} (${plugin_source})"
        wp plugin install "$plugin_source" --activate --allow-root
    elif ! wp plugin is-active "$plugin_slug" --allow-root; then
        echo "Activating custom plugin: ${plugin_name}"
        wp plugin activate "$plugin_slug" --allow-root
    else
        echo "Custom plugin already active: ${plugin_name}"
    fi
done

for theme in "${themes_install[@]}"; do
    IFS='|' read -r theme_name theme_slug theme_source <<< "$theme"

    if [[ -z "${theme_source:-}" ]]; then
        theme_source="$theme_slug"
    fi

    if ! wp theme is-installed "$theme_slug" --allow-root; then
        echo "Installing custom theme: ${theme_name} (${theme_source})"
        wp theme install "$theme_source" --activate --allow-root
    else
        echo "Custom theme already installed: ${theme_name}"
    fi
done

for plugin in "${plugins_activate_only[@]}"; do
    IFS='|' read -r plugin_name plugin_slug <<< "$plugin"

    activation_flag="${STATE_DIR}/.${plugin_slug}.activated"

    if [[ -f "$activation_flag" ]]; then
        continue
    fi

    if wp plugin is-installed "$plugin_slug" --allow-root; then
        if ! wp plugin is-active "$plugin_slug" --allow-root; then
            echo "Activating plugin once: ${plugin_name}"
            wp plugin activate "$plugin_slug" --allow-root
        fi

        touch "$activation_flag"
    fi
done

for theme in "${themes_activate_only[@]}"; do
    IFS='|' read -r theme_name theme_slug <<< "$theme"

    activation_flag="${STATE_DIR}/.${theme_slug}.theme.activated"

    if [[ -f "$activation_flag" ]]; then
        continue
    fi

    if wp theme is-installed "$theme_slug" --allow-root; then
        echo "Activating theme once: ${theme_name}"
        wp theme activate "$theme_slug" --allow-root
        touch "$activation_flag"
    fi
done
