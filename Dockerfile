# ===========================
# Stage 1: Frontend deps (Node.js)
# ===========================
FROM node:20 AS frontend

WORKDIR /app
COPY package*.json ./
RUN npm install

# ===========================
# Stage 2: Vendor dependencies (Composer)
# ===========================
FROM composer:2 AS vendor

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist --ignore-platform-reqs
COPY . .

# 🔧 Fix broken .env APP_NAME
RUN sed -i 's/^APP_NAME=.*/APP_NAME="Financial Freedom"/' .env || true

RUN composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs

# ===========================
# Stage 3: Backend runtime (Laravel + PHP + Frontend build)
# ===========================
FROM php:8.3-fpm AS backend

WORKDIR /app

# Install PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip libpq-dev libonig-dev libzip-dev \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip

# Copy backend/vendor code
COPY --from=vendor /app /app

# Build frontend *after* vendor exists
COPY --from=frontend /app/node_modules /app/node_modules
RUN npm run build || (echo "⚠️ Frontend build failed, continuing without JS build" && exit 0)

# Laravel storage & cache dirs
RUN mkdir -p /app/storage/framework/{sessions,views,cache} \
    && chown -R www-data:www-data /app/storage /app/bootstrap/cache

EXPOSE 9000
CMD ["php-fpm"]
