# ================================
# Stage 1 - Frontend build (Node)
# ================================
FROM node:20 AS frontend

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build || echo "⚠️ Frontend build failed, continuing..."

# ================================
# Stage 2 - PHP dependencies (Composer)
# ================================
FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist --ignore-platform-reqs

COPY . .
RUN composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs

# ================================
# Stage 3 - PHP runtime + Nginx + Supervisor
# ================================
FROM php:8.3-fpm AS backend

# Install system dependencies, nginx, supervisor, and PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip libpq-dev libonig-dev libzip-dev \
    nginx curl supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy PHP + Node + Nginx/Supervisor configs
COPY --from=vendor /app /app
COPY --from=frontend /app/public /app/public
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Permissions for Laravel storage & cache
RUN mkdir -p /app/storage/framework/{sessions,views,cache} \
    && chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Expose HTTP port
EXPOSE 80

# Run supervisor (which manages php-fpm + nginx)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
