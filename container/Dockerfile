# SPDX-License-Identifier: AGPL-3.0-or-later

FROM wordpress:6.8-php8.3-fpm@sha256:906c25725c2edccb7809851f61f98560ea73b6c01d482d69d1b9fdf04b5ff75f

USER root

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        nginx \
        redis-server \
        git \
        curl \
        wget \
        netcat-openbsd \
        procps \
        acl \
        libfreetype6-dev \
        libxml2-dev \
        libpng-dev \
        zlib1g-dev \
        libonig-dev \
        libgd-dev \
        libicu-dev \
        libgmp-dev \
        libfcgi0ldbl \
    && docker-php-ext-install soap \
    && docker-php-ext-install mbstring \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install opcache \
    && docker-php-ext-install mysqli \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
    && docker-php-ext-install -j"$(nproc)" gd \
    && docker-php-ext-install gmp \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://getcomposer.org/installer \
    | php -- --install-dir=/usr/local/bin --filename=composer

RUN wget -O /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

ARG ACORE_CMS_REPO=https://github.com/azerothcore/acore-cms.git
ARG ACORE_CMS_COMMIT=cac98762374784b4c2ae0d817f5744ab6b5d5bd5

RUN git clone "$ACORE_CMS_REPO" /tmp/acore-cms \
    && cd /tmp/acore-cms \
    && git checkout "$ACORE_CMS_COMMIT" \
    && mkdir -p /opt/acore-cms \
    && cp -a src/acore-wp-plugin /opt/acore-cms/acore-wp-plugin \
    && printf '%s\n' "$ACORE_CMS_COMMIT" > /opt/acore-cms/ACORE_CMS_COMMIT \
    && chown -R www-data:www-data /opt/acore-cms \
    && rm -rf /tmp/acore-cms

ARG WOOCOMMERCE_VERSION=10.7.0
ARG WP_GRAPHQL_VERSION=2.23.0
ARG WPGRAPHQL_ACF_VERSION=3.0.0
ARG MYCRED_VERSION=3.2.6
ARG ACF_VERSION=6.8.10
ARG WORDPRESS_IMPORTER_VERSION=0.9.6

ARG WOOCOMMERCE_SHA256=3c3d72be3a2b7fe4b26d34c09c572f6bc0b230d2b69b968307fca41aaeef8bee
ARG WP_GRAPHQL_SHA256=27b706aa480c926eb16c537843e179da494154da6f0aaf7a4dd28edad70f1403
ARG WPGRAPHQL_ACF_SHA256=a9f9ddaf892c691745a6ac38a12a4c81ded89ba91f04069cf228bb6554ee580b
ARG MYCRED_SHA256=13ce9ef2cab18e92cc0485702f63a11e1c732a1be291c2b57f9822f8286f5609
ARG ACF_SHA256=92d51a8f1d839f60aee4efb6a9cd269b37d1599a9fb44d03f792352dfe34c744
ARG WORDPRESS_IMPORTER_SHA256=85cfad65e24eb3b25ed536f52ce52c3971bd42a852d6f2c6a5bea8c5c429c323

RUN mkdir -p /opt/acore-cms/plugins \
    && curl -fL \
        "https://downloads.wordpress.org/plugin/woocommerce.${WOOCOMMERCE_VERSION}.zip" \
        -o "/opt/acore-cms/plugins/woocommerce-${WOOCOMMERCE_VERSION}.zip" \
    && curl -fL \
        "https://downloads.wordpress.org/plugin/wp-graphql.${WP_GRAPHQL_VERSION}.zip" \
        -o "/opt/acore-cms/plugins/wp-graphql-${WP_GRAPHQL_VERSION}.zip" \
    && curl -fL \
        "https://downloads.wordpress.org/plugin/wpgraphql-acf.${WPGRAPHQL_ACF_VERSION}.zip" \
        -o "/opt/acore-cms/plugins/wpgraphql-acf-${WPGRAPHQL_ACF_VERSION}.zip" \
    && curl -fL \
        "https://downloads.wordpress.org/plugin/mycred.${MYCRED_VERSION}.zip" \
        -o "/opt/acore-cms/plugins/mycred-${MYCRED_VERSION}.zip" \
    && curl -fL \
        "https://downloads.wordpress.org/plugin/advanced-custom-fields.${ACF_VERSION}.zip" \
        -o "/opt/acore-cms/plugins/advanced-custom-fields-${ACF_VERSION}.zip" \
    && curl -fL \
        "https://downloads.wordpress.org/plugin/wordpress-importer.${WORDPRESS_IMPORTER_VERSION}.zip" \
        -o "/opt/acore-cms/plugins/wordpress-importer-${WORDPRESS_IMPORTER_VERSION}.zip" \
    && echo "${WOOCOMMERCE_SHA256}  /opt/acore-cms/plugins/woocommerce-${WOOCOMMERCE_VERSION}.zip" | sha256sum -c - \
    && echo "${WP_GRAPHQL_SHA256}  /opt/acore-cms/plugins/wp-graphql-${WP_GRAPHQL_VERSION}.zip" | sha256sum -c - \
    && echo "${WPGRAPHQL_ACF_SHA256}  /opt/acore-cms/plugins/wpgraphql-acf-${WPGRAPHQL_ACF_VERSION}.zip" | sha256sum -c - \
    && echo "${MYCRED_SHA256}  /opt/acore-cms/plugins/mycred-${MYCRED_VERSION}.zip" | sha256sum -c - \
    && echo "${ACF_SHA256}  /opt/acore-cms/plugins/advanced-custom-fields-${ACF_VERSION}.zip" | sha256sum -c - \
    && echo "${WORDPRESS_IMPORTER_SHA256}  /opt/acore-cms/plugins/wordpress-importer-${WORDPRESS_IMPORTER_VERSION}.zip" | sha256sum -c -

COPY container/nginx.conf /etc/nginx/pelican.conf.template

COPY --chmod=755 \
    container/entrypoint.sh \
    /usr/local/bin/pelican-entrypoint.sh

COPY --chmod=755 \
    container/start.sh \
    /usr/local/bin/pelican-start.sh

COPY --chmod=755 \
    container/custom-init.sh \
    /usr/local/bin/pelican-custom-init.sh

RUN rm -f /etc/nginx/sites-enabled/default \
    && mkdir -p /home/container/wordpress \
    && chown -R www-data:www-data /home/container

EXPOSE 8080

STOPSIGNAL SIGTERM

ENTRYPOINT ["/usr/local/bin/pelican-entrypoint.sh"]
CMD ["/usr/local/bin/pelican-start.sh"]
