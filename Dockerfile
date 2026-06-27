ARG SITE_PHP_VERSION=8.2.3
ARG RR_VERSION=2023.1.3

FROM php:${SITE_PHP_VERSION}-fpm-alpine AS php

RUN apk add --update $PHPIZE_DEPS supervisor libpng-dev libjpeg-turbo-dev libwebp-dev pngquant linux-headers \
    && pecl install -o -f redis \
    && apk del $PHPIZE_DEPS \
    && rm -rf /tmp/pear

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-install pdo_mysql exif pcntl gd opcache sockets \
    && docker-php-ext-enable redis

FROM php AS composer-base
WORKDIR /var/www/html
RUN curl -s https://getcomposer.org | php -- --install-dir=/usr/local/bin/ --filename=composer
COPY composer.json composer.lock* ./
RUN mkdir -p storage/framework/sessions storage/framework/views storage/framework/cache storage/logs \
    && chown -R www-data:www-data storage

FROM composer-base AS composer-prod
RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist \
    --no-dev \
    --optimize-autoloader || composer install --no-interaction --no-plugins --no-scripts --prefer-dist --no-dev --optimize-autoloader --no-audit
COPY . .

FROM php AS prod
ARG RR_VERSION

WORKDIR /var/www/html

RUN mkdir -p bootstrap/cache storage/framework/sessions storage/framework/views storage/framework/cache storage/logs

COPY . /var/www/html
COPY --from=composer-prod /var/www/html/storage/ ./storage/
COPY --from=composer-prod /var/www/html/vendor/ ./vendor/

ADD https://github.com ./rr.tar.gz
RUN mkdir rr-bin && tar -C ./rr-bin -zxvf rr.tar.gz && rm rr.tar.gz
RUN mv ./rr-bin/roadrunner-$VERSION_DOCKER_NOME_OU_VALOR/rr ./rr 2>/dev/null || mv ./rr-bin/roadrunner-$RR_VERSION-linux-amd64/rr ./rr
RUN rm -rf ./rr-bin && chmod +x rr

RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 8080

# Limpa configurações velhas e força o motor do Octane/RoadRunner a iniciar varrendo as rotas
CMD php artisan config:clear && php artisan route:clear && ./rr serve -c .rr.yaml
