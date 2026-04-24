# syntax=docker/dockerfile:1

################################################################################
# Composer Deps Stage
################################################################################

FROM composer:lts AS deps

WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --ignore-platform-reqs

################################################################################
# PHP Build Stage
################################################################################

FROM php:8.3-apache AS final

LABEL org.opencontainers.image.source=https://github.com/adam-rms/adam-rms
LABEL org.opencontainers.image.documentation=https://adam-rms.com/self-hosting
LABEL org.opencontainers.image.url=https://adam-rms.com
LABEL org.opencontainers.image.vendor="Bithell Studios Ltd."
LABEL org.opencontainers.image.description="AdamRMS is a free, open source advanced Rental Management System for Theatre, AV & Broadcast. This image is a PHP Apache2 docker container, which exposes AdamRMS on port 80."
LABEL org.opencontainers.image.licenses=AGPL-3.0

# Install PHP extensions
RUN apt-get update && apt-get install -y \
    libicu-dev \
    libzip-dev \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql mysqli intl zip

# Fix Apache MPM conflict
RUN sed -i 's/^LoadModule mpm_event/#LoadModule mpm_event/g' /etc/apache2/mods-enabled/mpm_event.load 2>/dev/null || true
RUN a2dismod mpm_event || true
RUN a2dismod mpm_worker || true
RUN a2enmod mpm_prefork || true
RUN a2enmod rewrite || true

# Copy our php.ini file
RUN echo "\npost_max_size=64M\n" >> "$PHP_INI_DIR/php.ini"
RUN echo "memory_limit=256M\n" >> "$PHP_INI_DIR/php.ini"
RUN echo "max_execution_time=600\n" >> "$PHP_INI_DIR/php.ini"
RUN echo "sys_temp_dir=/tmp\n" >> "$PHP_INI_DIR/php.ini"
RUN echo "upload_max_filesize=64M\n" >> "$PHP_INI_DIR/php.ini"

# Set document root
RUN sed -ri -e 's!/var/www/html!/var/www/html/src!g' /etc/apache2/sites-available/*.conf

# Copy the app dependencies from the previous install stage.
COPY --from=deps app/vendor/ /var/www/html/vendor
# Copy the app files from the app directory.
COPY ./src /var/www/html/src

# Copy the database related files
COPY ./db /var/www/html/db
COPY ./phinx.php /var/www/html
COPY ./migrate.sh /var/www/html
RUN chmod +x /var/www/html/migrate.sh

SHELL ["sh"]
ENTRYPOINT ["/var/www/html/migrate.sh"]
