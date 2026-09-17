# Pelican ACore-CMS

A Pelican Panel-ready container and egg for running [AzerothCore ACore-CMS](https://github.com/azerothcore/acore-cms) with WordPress, nginx, PHP-FPM, and Redis in a single container.

This project is designed for Pelican/Wings deployments and keeps the ACore-CMS plugin pinned to a tested upstream revision.

## Features

- Pelican-compatible ACore-CMS container
- WordPress 6.8.3
- PHP 8.3
- nginx
- Redis
- WordPress Multisite enabled by default
- Subdirectory Multisite by default
- Pinned ACore-CMS upstream commit
- Pinned WordPress dependency plugin versions
- SHA-256 verification for downloaded dependency plugins
- Pinned Composer
- Pinned WP-CLI
- Pinned PHP Redis extension
- Built-in container healthcheck
- Persistent WordPress, Redis, configuration, and log data under `/home/container`
- Supports external WordPress MySQL/MariaDB databases
- Supports AzerothCore SOAP integration
- Supports AzerothCore auth, characters, and world databases
- Optional custom plugin/theme initialization through `/home/container/conf/init`

## Container Image

Development image:

    ghcr.io/sintheticgaming/pelican-acore-cms:dev

The `dev` tag should be considered a development/testing image until the first stable release is published.

## Requirements

You will need:

- Pelican Panel
- Pelican Wings
- A MySQL or MariaDB server for WordPress
- An existing AzerothCore installation
- AzerothCore SOAP enabled
- Network access from the CMS container to the AzerothCore database server
- Network access from the CMS container to the AzerothCore SOAP port

## Pelican Egg

The Pelican egg is located at:

    egg/egg-acore-cms.json

Import this egg into Pelican Panel and create a server using:

    ghcr.io/sintheticgaming/pelican-acore-cms:dev

Only one Pelican allocation is required for the web service.

Redis and PHP-FPM remain internal to the container and do not require additional allocations.

## WordPress Database

Create a dedicated WordPress database and user.

Example:

    CREATE DATABASE acore_cms
      CHARACTER SET utf8mb4
      COLLATE utf8mb4_unicode_ci;

    CREATE USER 'acore_cms'@'%' IDENTIFIED BY 'CHANGE_ME';

    GRANT ALL PRIVILEGES ON acore_cms.*
    TO 'acore_cms'@'%';

    FLUSH PRIVILEGES;

For production environments, restrict the MySQL user host as appropriate for your network instead of using `%` when possible.

## Pelican Variables

The egg exposes the following WordPress settings:

    WORDPRESS_DB_HOST
    WORDPRESS_DB_PORT
    WORDPRESS_DB_NAME
    WORDPRESS_DB_USER
    WORDPRESS_DB_PASSWORD

    WORDPRESS_URL
    WORDPRESS_TITLE

    WORDPRESS_ADMIN_USER
    WORDPRESS_ADMIN_PASSWORD
    WORDPRESS_ADMIN_EMAIL

    WORDPRESS_MULTISITE
    WORDPRESS_MULTISITE_USE_SUBDOMAINS

Example:

    WORDPRESS_DB_HOST=192.168.1.100
    WORDPRESS_DB_PORT=3306
    WORDPRESS_DB_NAME=acore_cms
    WORDPRESS_DB_USER=acore_cms

    WORDPRESS_URL=http://192.168.1.50:8081

    WORDPRESS_MULTISITE=true
    WORDPRESS_MULTISITE_USE_SUBDOMAINS=false


## WordPress Multisite

Multisite is enabled by default:

    WORDPRESS_MULTISITE=true

Subdirectory mode is enabled by default:

    WORDPRESS_MULTISITE_USE_SUBDOMAINS=false

Multisite support is intentionally retained because ACore-CMS can use separate WordPress sites for multiple AzerothCore realms.

If you only operate a single realm, Multisite can be disabled before the initial WordPress installation.

Changing Multisite mode after WordPress has already been installed is not recommended.

## AzerothCore SOAP

Enable SOAP in your AzerothCore `worldserver.conf`:

    SOAP.Enabled = 1
    SOAP.IP = "0.0.0.0"
    SOAP.Port = 7878

Create a dedicated SOAP account in AzerothCore and give it the required GM security level.

Example account name:

    cmssoap

Do not reuse a personal administrator account for CMS SOAP access.

Configure ACore-CMS with:

    SOAP Host: AzerothCore server IP or hostname
    SOAP Port: 7878
    SOAP Username: cmssoap
    SOAP Password: your SOAP password

## AzerothCore Databases

ACore-CMS requires access to:

    acore_auth
    acore_characters
    acore_world

Configure these from the ACore-CMS settings page in WordPress.

Example:

    Auth Database:
    Host: 192.168.1.100
    Port: 3306
    Database: acore_auth

    Characters Database:
    Host: 192.168.1.100
    Port: 3306
    Database: acore_characters

    World Database:
    Host: 192.168.1.100
    Port: 3306
    Database: acore_world

A dedicated CMS database account with only the permissions required by ACore-CMS is recommended for production deployments.

## SOAP Firewall Security

Do not expose AzerothCore SOAP port `7878` to the public internet.

If your Pelican containers use a dedicated Docker network, allow only that network to access SOAP.

Example using firewalld:

    sudo firewall-cmd --permanent --remove-port=7878/tcp

    sudo firewall-cmd --permanent \
      --add-rich-rule='rule family="ipv4" source address="172.18.0.0/16" port port="7878" protocol="tcp" accept'

    sudo firewall-cmd --reload

Replace `172.18.0.0/16` with the Docker subnet used by your Pelican installation.

You can inspect it with:

    docker network inspect pelican_nw \
      --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'

## Redis Host Recommendation

Redis recommends enabling Linux memory overcommit on the Wings host.

Set:

    sudo sysctl -w vm.overcommit_memory=1

To make it persistent:

    echo 'vm.overcommit_memory = 1' \
      | sudo tee /etc/sysctl.d/99-redis.conf

    sudo sysctl --system

Verify:

    sysctl vm.overcommit_memory

Expected:

    vm.overcommit_memory = 1

## Persistent Data

Persistent application data lives under:

    /home/container

Important paths include:

    /home/container/wordpress
    /home/container/redis
    /home/container/conf
    /home/container/conf/init
    /home/container/conf/nginx
    /home/container/logs

WordPress files and Redis persistence survive container recreation.

## Redis

Redis is embedded in the container and listens only on:

    127.0.0.1:6379

Redis persistence is stored at:

    /home/container/redis/dump.rdb

Redis is not exposed through a Pelican allocation.

## nginx

nginx listens on the Pelican-provided `SERVER_PORT`.

The generated server configuration is written to:

    /home/container/conf/nginx/server.conf

This design allows the image to work with Pelican's read-only container root filesystem.

## Healthcheck

The image includes a Docker healthcheck.

It verifies:

- nginx responds on `/healthz`
- PHP-FPM is listening on port `9000`
- Redis responds with `PONG`

The health endpoint is:

    /healthz

A healthy container should report:

    healthy

through Docker.

## Required WordPress Plugins

The following versions are bundled and pinned:

| Plugin | Version |
| --- | ---: |
| WooCommerce | 10.7.0 |
| WPGraphQL | 2.23.0 |
| WPGraphQL ACF | 3.0.0 |
| myCred | 3.2.6 |
| Advanced Custom Fields | 6.8.10 |
| WordPress Importer | 0.9.6 |

The plugin ZIP files are downloaded during the image build and verified with SHA-256 checksums.

They are installed locally from the image during first startup instead of being downloaded from WordPress.org at runtime.

## Tested Versions

Current tested stack:

    WordPress:        6.8.3
    PHP:              8.3
    Composer:         2.10.3
    WP-CLI:           2.12.0
    PHP Redis:        6.3.0
    Redis Server:     8.0.2
    ACore-CMS Plugin: 0.1

Pinned upstream ACore-CMS commit:

    cac98762374784b4c2ae0d817f5744ab6b5d5bd5

The complete tested dependency information is stored in:

    versions/acore-cms.lock.json

## Custom Plugins and Themes

Additional plugins and themes can be initialized through configuration files placed in:

    /home/container/conf/init

Example:

    themes_install+=(
        "Twenty Twenty-Four|twentytwentyfour"
    )

These configuration files are sourced as shell scripts inside the container.

Only trusted server administrators should be allowed to modify them.

## ACore-CMS Account Registration

ACore-CMS uses normal WordPress authentication and registration hooks to create AzerothCore accounts.

The default WordPress/Multisite signup and activation flow remains unchanged.

After activation, logging in through the standard WordPress login form can trigger ACore account creation.

The default login page is:

    /wp-login.php

A custom front-end login/registration experience is not currently included in this project.

Server owners may install their own WordPress theme or account frontend plugin.

## Email / Account Activation

WordPress Multisite normally requires account activation through email.

For production use, configure WordPress SMTP or another reliable mail delivery solution.

This project does not currently bundle an SMTP plugin or mail server.

## First Startup

On first startup, the container:

1. Initializes persistent WordPress files.
2. Creates `wp-config.php`.
3. Installs WordPress or WordPress Multisite.
4. Installs the bundled dependency plugins.
5. Activates the ACore-CMS plugin.
6. Loads optional initialization files.
7. Generates the nginx server configuration.
8. Starts Redis.
9. Starts PHP-FPM.
10. Starts nginx.

Successful startup ends with:

    All services started.

## Updates

This project intentionally pins major dependencies to tested versions.

Do not assume that manually updating WordPress, ACore-CMS, or required plugins through the WordPress dashboard will remain compatible with the tested image.

Future wrapper releases should update:

    versions/acore-cms.lock.json

after compatibility testing.

The required ACore-CMS dependency plugins are image-managed and may be restored to tested versions by future releases.

## Backups

At minimum, back up:

    /home/container

and the WordPress database.

For a complete installation, also maintain normal backups of your AzerothCore databases separately.

## Security Notes

For production installations:

- Do not expose SOAP port `7878` publicly.
- Use dedicated database accounts.
- Use strong unique passwords.
- Use HTTPS through a reverse proxy.
- Restrict database access to trusted networks.
- Keep Pelican, Wings, Docker, WordPress, and AzerothCore patched.
- Do not commit secrets to Git.
- Rotate any credentials accidentally exposed in logs or terminals.
- Configure reliable WordPress email delivery for account activation and password resets.

## Project Structure

    container/
      Dockerfile
      entrypoint.sh
      start.sh
      custom-init.sh
      nginx.conf
      nginx-main.conf

    egg/
      egg-acore-cms.json

    versions/
      acore-cms.lock.json

## Upstream Projects

This project builds on:

- AzerothCore
- ACore-CMS
- WordPress
- Pelican Panel
- nginx
- Redis
- WP-CLI
- Composer

ACore-CMS upstream:

    https://github.com/azerothcore/acore-cms

## License

This project is licensed under the GNU Affero General Public License v3.0 or later (`AGPL-3.0-or-later`).

It includes and integrates software from third-party projects with their own licenses. See the upstream projects and bundled components for their respective licensing terms.
