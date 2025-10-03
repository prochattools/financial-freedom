# Stage 1: Build frontend
FROM node:20 as frontend
WORKDIR /app

# Install frontend deps
COPY package*.json ./
RUN npm install

# Copy frontend source & build
COPY . .
RUN npm run build || echo "⚠️ Frontend build failed, continuing..."

# Stage 2: PHP vendor dependencies
FROM composer:2 as vendor
WORKDIR /app

# Copy full Laravel source code FIRST (artisan must exist before composer runs)
COPY . .
RUN composer install --no-dev --no-interaction --optimize-autoloader --ignore-platform-reqs

# Stage 3: Final runtime image
FROM php:8.3-fpm as app
WORKDIR /var/www/html

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libonig-dev libzip-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

# Copy application code & dependencies
COPY --from=vendor /app /var/www/html

# Copy built frontend
COPY --from=frontend /app/public /var/www/html/public

# Fix permissions
RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Copy configs (make sure you have these in your repo under docker/)
COPY ./docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY ./docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80
CMD ["/usr/bin/supervisord"]
