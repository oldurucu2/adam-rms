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

FROM ubuntu:22.04 AS final

LABEL org.opencontainers.image.source=https://github.com/adam-rms/adam-rms

ENV DEBIAN_FRONTEND=noninteractive

# Install Apache, PHP 8.3 and extensions
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository ppa:ondrej/php \
    && apt-get update && apt-get install -y \
    apache2 \
    php8.3 \
    php8.3-mysql \
    php8.3-gd \
    php8.3-intl \
    php8.3-zip \
    php8.3-xml \
    libapache2-mod-php8.3 \
    && rm -rf /var/lib/apt/lists/*

# Fix Apache MPM
RUN a2dismod mpm_event mpm_worker 2>/dev/null; \
    a2enmod mpm_prefork php8.3 rewrite

# PHP ini settings
RUN echo "post_max_size=64M" >> /etc/php/8.3/apache2/php.ini \
    && echo "memory_limit=256M" >> /etc/php/8.3/apache2/php.ini \
    && echo "max_execution_time=600" >> /etc/php/8.3/apache2/php.ini \
    && echo "sys_temp_dir=/tmp" >> /etc/php/8.3/apache2/php.ini \
    && echo "upload_max_filesize=64M" >> /etc/php/8.3/apache2/php.ini

# Set document root
RUN sed -ri -e 's!/var/www/html!/var/www/html/src!g' /etc/apache2/sites-available/*.conf

# Enable apache mod rewrite
RUN a2enmod rewrite

# Create session directory with correct permissions
RUN mkdir -p /var/lib/php/sessions && chmod 1777 /var/lib/php/sessions

# Copy application files
COPY --from=deps /app/vendor/ /var/www/html/vendor
COPY ./src /var/www/html/src
COPY ./db /var/www/html/db
COPY ./phinx.php /var/www/html
COPY ./migrate.sh /var/www/html

RUN chmod +x /var/www/html/migrate.sh

EXPOSE 80

SHELL ["/bin/bash", "-c"]
ENTRYPOINT ["/var/www/html/migrate.sh"]
