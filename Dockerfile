# Stage 1: PHP dependencies
FROM composer:2 as phpdeps
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist
COPY . ./
RUN composer dump-autoload --optimize

# Stage 2: Node frontend build
FROM node:20 as frontend
WORKDIR /app
COPY package*.json vite.config.js ./
COPY resources ./resources
COPY public ./public
COPY --from=phpdeps /app/vendor ./vendor
RUN npm ci || npm install
RUN npm run build

# Stage 3: Runtime (PHP + Nginx)
FROM php:8.3-fpm

# Install required packages
RUN apt-get update && apt-get install -y \
    nginx supervisor curl unzip git libzip-dev \
 && docker-php-ext-install pdo pdo_mysql zip \
 && rm -rf /var/lib/apt/lists/*

# Workdir
WORKDIR /var/www/html

# Copy Laravel + vendor
COPY --from=phpdeps /app ./
# Copy frontend build
COPY --from=frontend /app/public/build ./public/build

# Configure Nginx
COPY ./docker/nginx.conf /etc/nginx/nginx.conf
COPY ./docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Fix permissions
RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
 && chown -R www-data:www-data /var/www/html \
 && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 80
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
