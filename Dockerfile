# =============================
# Stage 1: PHP Dependencies
# =============================
FROM composer:2 AS vendor

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist --ignore-platform-reqs
COPY . .
RUN composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs

# =============================
# Stage 2: Frontend (Vite)
# =============================
FROM node:20 AS frontend

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build || echo "⚠️ Frontend build failed, continuing..."

# =============================
# Stage 3: Backend (PHP-FPM + Nginx + Supervisor)
# =============================
FROM php:8.3-fpm AS backend

# Install dependencies
RUN apt-get update && apt-get install -y \
    git unzip libpq-dev libonig-dev libzip-dev \
    nginx curl supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy PHP dependencies and frontend build
COPY --from=vendor /app /app
COPY --from=frontend /app/public /app/public

# Configure PHP-FPM to listen on 127.0.0.1:9000
RUN echo "listen = 127.0.0.1:9000" > /usr/local/etc/php-fpm.d/zz-docker.conf

# Copy Nginx + Supervisor configs
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Ensure Laravel storage is writable
RUN mkdir -p /app/storage/framework/{sessions,views,cache} \
    && chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Expose HTTP port
EXPOSE 80

# Run migrations automatically (optional, safe to remove if handled elsewhere)
RUN php artisan migrate --force || true

# Start Supervisor (manages Nginx + PHP-FPM)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
