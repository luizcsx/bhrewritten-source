FROM php:8.2-cli

RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    zip \
    unzip \
    git \
    curl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd pdo pdo_mysql exif pcntl sockets

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

EXPOSE 8080

# Comando que limpa configurações antigas e inicia o motor do RoadRunner
CMD php artisan config:clear && php artisan route:clear && ./rr serve -c .rr.yaml
