# syntax=docker/dockerfile:1

# ---------- Etapa 1: dependencias de Composer ----------
FROM composer:2 AS vendor
WORKDIR /app
# Solo los manifiestos: la capa se cachea mientras composer.lock no cambie
COPY composer.json composer.lock ./
RUN --mount=type=cache,target=/tmp/cache \
    composer install --no-dev --no-interaction --no-scripts --no-autoloader \
      --prefer-dist
# Con el código fuente ya se puede generar el autoloader optimizado
COPY . .
RUN composer dump-autoload --no-dev --optimize --classmap-authoritative --no-scripts

# ---------- Etapa 2: runtime PHP-FPM ----------
FROM php:8.3-fpm-alpine AS app

# pdo_mysql es la única extensión que no viene compilada en la imagen oficial.
# mbstring, openssl, tokenizer, xml, ctype y json ya vienen incluidas; se verifican abajo.
RUN docker-php-ext-install -j"$(nproc)" pdo_mysql opcache \
    && php -r 'foreach (["pdo_mysql","mbstring","openssl","tokenizer","xml","ctype","json"] as $e) { if (!extension_loaded($e)) { fwrite(STDERR, "Falta la extension $e\n"); exit(1); } }'

COPY docker/php.ini /usr/local/etc/php/conf.d/zz-app.ini

WORKDIR /var/www/html
# vendor/ proviene de la etapa de build; no hay Composer en la imagen final
COPY --from=vendor --chown=www-data:www-data /app/vendor ./vendor
COPY --chown=www-data:www-data . .
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache

USER www-data
EXPOSE 9000
ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]

# ---------- Etapa 3: proxy inverso Nginx ----------
FROM nginx:1.27-alpine AS web
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
