FROM instrumentisto/flutter:3.22.0 AS build

WORKDIR /app

# Copy dependency files first for better layer caching
COPY pubspec.yaml .
RUN flutter pub get

# Copy source code
COPY . .

# Build for web (can be served by nginx or similar)
# For Android APK, this step must be replaced by a local build:
#   flutter build apk --release
RUN flutter build web --release --dart-define=API_BASE_URL=http://localhost:8000

# ── Serve with nginx ──────────────────────────────────────────────────────────
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
