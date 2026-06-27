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

ARG RR_VERSION=2023.1.3
ADD https://github.com ./rr.tar.gz
RUN mkdir rr-bin && tar -C ./rr-bin -zxvf rr.tar.gz && rm rr.tar.gz \
    && mv ./rr-bin/roadrunner-$RR_VERSION-linux-amd64/rr ./rr \
    && rm -rf ./rr-bin && chmod +x rr

RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 8080

# Comando que limpa configurações antigas e inicia o motor do RoadRunner puxando as rotas da pasta public
CMD php artisan config:clear && php artisan route:clear && ./rr serve -c .rr.yaml
