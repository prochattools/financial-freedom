# ================================
# 1. Frontend build stage
# ================================
FROM node:20 AS frontend
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build || echo "⚠️ Frontend build failed, continuing..."

# ================================
# 2. Backend dependencies (Composer)
# ================================
FROM composer:2 AS vendor
WORKDIR /app
COPY . .   # 👈 copy the full app so artisan exists
RUN composer install --no-dev --no-interaction --optimize-autoloader || true

# ================================
# 3. Runtime (PHP + Nginx + Supervisor)
# ================================
FROM php:8.3-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libonig-dev libzip-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

# Copy app
COPY . .

# Copy built frontend assets
COPY --from=frontend /app/public/js ./public/js
COPY --from=frontend /app/public/css ./public/css

# Copy vendor
COPY --from=vendor /app/vendor ./vendor

# Configs
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Fix permissions
RUN mkdir -p storage bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

EXPOSE 80
CMD ["/usr/bin/supervisord"]
