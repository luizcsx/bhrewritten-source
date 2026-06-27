FROM php:8.2-fpm-alpine

RUN apk add --no-cache libpng-dev libjpeg-turbo-dev freetype-dev bash curl git unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql exif pcntl gd sockets

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY --from=spiralscout/roadrunner:2023.3 /usr/bin/rr /var/www/html/rr

WORKDIR /var/www/html

RUN mkdir -p bootstrap/cache storage/framework/sessions storage/framework/views storage/framework/cache storage/logs

COPY . /var/www/html

RUN composer install \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist \
    --no-dev \
    --optimize-autoloader

RUN chmod +x /var/www/html/rr

RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 10000

# Comando direto para iniciar o servidor RoadRunner de forma estável
CMD ["./rr", "serve", "-c", ".rr.yaml"]
