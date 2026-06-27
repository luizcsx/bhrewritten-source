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
WORKDIR /app
RUN curl -s https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin/ --filename=composer
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
RUN composer dump-autoload -o

FROM php AS prod
ARG RR_VERSION

WORKDIR /var/www/html

COPY . /var/www/html
COPY --from=composer-prod /app/storage/ ./storage/
COPY --from=composer-prod /app/bootstrap/cache/ ./bootstrap/cache
COPY --from=composer-prod /app/vendor/ ./vendor/

ADD https://github.com/roadrunner-server/roadrunner/releases/download/v$RR_VERSION/roadrunner-$RR_VERSION-linux-amd64.tar.gz ./rr.tar.gz
RUN mkdir rr-bin && tar -C ./rr-bin -zxvf rr.tar.gz && rm rr.tar.gz
RUN mv ./rr-bin/roadrunner-$RR_VERSION-linux-amd64/rr . && \
    rm -rf ./rr-bin && \
    chmod +x rr

RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 8080

CMD ["./rr", "serve", "-c", ".rr.yaml"]
