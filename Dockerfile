# ===========================
# Stage 1: Vendor dependencies (Composer)
# ===========================
FROM composer:2 AS vendor

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist --ignore-platform-reqs
COPY . .
RUN composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs


# ===========================
# Stage 2: Frontend build (Node + Ziggy requires vendor)
# ===========================
FROM node:20 AS frontend

WORKDIR /app
COPY package*.json ./
RUN npm install

# Copy source code AND vendor from previous stage so Ziggy works
COPY . .
COPY --from=vendor /app/vendor ./vendor

RUN npm run build


# ===========================
# Stage 3: Backend runtime (Laravel + PHP)
# ===========================
FROM php:8.3-fpm AS backend

# Install required extensions
RUN apt-get update && apt-get install -y \
    git unzip libpq-dev libonig-dev libzip-dev \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip

WORKDIR /var/www/html

# Copy application code, vendor, and built frontend assets
COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY --from=frontend /app/public/js ./public/js
COPY --from=frontend /app/public/css ./public/css

# Laravel optimizations
RUN php artisan config:clear && php artisan cache:clear && php artisan route:clear

CMD ["php-fpm"]
