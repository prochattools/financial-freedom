# Stage 1: Build frontend
FROM node:20 as frontend
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build || echo "⚠️ Frontend build failed, continuing..."

# Stage 2: Install PHP dependencies
FROM composer:2 as vendor
WORKDIR /app
COPY composer.json composer.lock ./
COPY . .                # 👈 Copy full Laravel code BEFORE composer install
RUN composer install --no-dev --no-interaction --optimize-autoloader

# Stage 3: Final PHP + Nginx image
FROM php:8.3-fpm as stage-2
WORKDIR /var/www/html

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libonig-dev libzip-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

# Copy vendor dependencies
COPY --from=vendor /app /var/www/html

# Copy frontend build
COPY --from=frontend /app/public /var/www/html/public

# Set permissions
RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Configure Nginx + Supervisor
COPY ./docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY ./docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80
CMD ["/usr/bin/supervisord"]
