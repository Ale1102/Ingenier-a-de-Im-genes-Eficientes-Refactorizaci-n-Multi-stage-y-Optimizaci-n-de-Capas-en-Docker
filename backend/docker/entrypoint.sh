#!/bin/sh
set -e

# Las variables de entorno solo existen en runtime: aquí se generan las cachés
php artisan config:cache
php artisan route:cache
php artisan view:cache

if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
  php artisan migrate --force
fi

exec "$@"
