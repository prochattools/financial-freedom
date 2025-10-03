# Frontend build stage
FROM node:20 AS frontend
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# PHP base stage
FROM php:8.3-fpm AS base
WORKDIR /var/www/html
RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libonig-dev libzip-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

COPY composer.json composer.lock ./
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
COPY . .
RUN composer install --no-dev --no-interaction --optimize-autoloader
RUN mkdir -p storage bootstrap/cache && chown -R www-data:www-data storage bootstrap/cache

# Copy frontend build
COPY --from=frontend /app/public/build /var/www/html/public/build

# Nginx + Supervisor config
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
