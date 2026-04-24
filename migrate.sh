#!/bin/bash

# This file is used by the docker container to build the database schema and seed the database with initial data

cd /var/www/html

# Validate expected environment variables
echo "AdamRMS - Checking for Environment Variables"
if [[ ! -v DB_HOSTNAME ]] || [[ ! -v DB_DATABASE ]] || [[ ! -v DB_USERNAME ]] || [[ ! -v DB_PASSWORD ]]; then
    echo "AdamRMS - Expected Environment Variables not set"
    exit 1
fi

# Database migration & seed
echo "AdamRMS - Starting Migration Script"

php vendor/bin/phinx migrate -e production
php vendor/bin/phinx seed:run -e production

if [[ -v DEV_MODE ]] && [[ "${DEV_MODE}" == 'true' ]]; then
    echo "AdamRMS - Running in DEV MODE"
fi

# Fix Apache MPM conflict
echo "AdamRMS - Fixing Apache MPM"
a2dismod mpm_event 2>/dev/null || true
a2dismod mpm_worker 2>/dev/null || true
a2enmod mpm_prefork 2>/dev/null || true

# Start Server
echo "AdamRMS - Starting Apache2"
apache2-foreground
