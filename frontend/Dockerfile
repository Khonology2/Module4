# Flutter Web Dockerfile for Render
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy Flutter project files
COPY . .

# Install dependencies
RUN flutter pub get

# Build Flutter web app with correct API URL
RUN flutter build web --release --base-href / --dart-define=API_BASE_URL=https://module4-api.onrender.com/api/v1

# Production stage - serve with nginx
FROM nginx:alpine

# Copy built web app to nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy nginx configuration for SPA routing
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
