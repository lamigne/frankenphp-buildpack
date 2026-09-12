# Example Dockerfile for FrankenPHP on Scalingo
# Copy this to your FrankenPHP app and rename to 'Dockerfile'

FROM dunglas/frankenphp:latest-alpine

WORKDIR /app

# Copy application files
COPY . /app

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader

# Create necessary directories
RUN mkdir -p /app/storage /app/bootstrap/cache && \
    chmod -R 755 /app/storage /app/bootstrap/cache

# Expose port (Scalingo uses 8080 by default)
EXPOSE 8080

# Start FrankenPHP with Caddy
CMD ["frankenphp", "run", "--config", "/app/Caddyfile"]
