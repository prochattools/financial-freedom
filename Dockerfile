# ------------------------
# Node stage: build frontend
# ------------------------
FROM node:20 AS frontend
WORKDIR /app

# Copy package files and install
COPY package*.json vite.config.js ./
RUN npm install

# ------------------------
# PHP base stage
# ------------------------
FROM php:8.3-fpm AS base

# Install system deps + PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libzip-dev libonig-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

# Copy composer first and install vendor deps
COPY composer.json composer.lock ./
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer install --no-dev --no-interaction --optimize-autoloader

# Copy full app
COPY . .

# ------------------------
# Frontend build (needs vendor/ziggy!)
# ------------------------
COPY --from=frontend /app/node_modules /app/node_modules
RUN npm run build || echo "⚠️ Frontend build failed, continuing..."

# Prepare Laravel storage & cache
RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# ------------------------
# Final runtime
# ------------------------
FROM base AS final

# Copy nginx & supervisord configs
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
