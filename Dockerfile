# Stage 1: Node (build frontend if any)
FROM node:20 AS frontend
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build || echo "⚠️ Frontend build failed, continuing..."

# Stage 2: PHP Composer
FROM composer:2 AS vendor
WORKDIR /app
COPY . .   # 👈 copy entire Laravel code including artisan
RUN composer install --no-dev --no-interaction --optimize-autoloader

# Stage 3: PHP-FPM + Nginx + Supervisor
FROM php:8.3-fpm AS production

# System deps
RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libonig-dev libzip-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

# Set workdir
WORKDIR /var/www/html

# Copy app from vendor stage
COPY --from=vendor /app ./

# Copy frontend build artifacts (if any)
COPY --from=frontend /app/public ./public

# Nginx config
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Supervisor config
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Permissions
RUN mkdir -p storage bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Ports
EXPOSE 80

# Run supervisor (manages php-fpm + nginx)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
