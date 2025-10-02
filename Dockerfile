# ===========================
# Stage 1: Frontend (Node.js)
# ===========================
FROM node:20 AS frontend

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# ===========================
# Stage 2: Vendor dependencies (Composer)
# ===========================
FROM composer:2 AS vendor

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist --ignore-platform-reqs
COPY . .

# 🔧 Fix broken .env file (APP_NAME with space needs quotes)
RUN sed -i 's/^APP_NAME=.*/APP_NAME="Financial Freedom"/' .env || true

RUN composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs

# ===========================
# Stage 3: Backend runtime (Laravel + PHP)
# ===========================
FROM php:8.3-fpm AS backend

WORKDIR /app

# Install PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip libpq-dev libonig-dev libzip-dev \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip

COPY --from=vendor /app /app
COPY --from=frontend /app/public/js /app/public/js
COPY --from=frontend /app/public/css /app/public/css

# Laravel storage & cache dirs
RUN mkdir -p /app/storage/framework/{sessions,views,cache} \
    && chown -R www-data:www-data /app/storage /app/bootstrap/cache

EXPOSE 9000
CMD ["php-fpm"
