
# Stage 1: Build Flutter Web
FROM debian:bookworm-slim AS build

# Install required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter 3.44.4 (includes Dart 3.12.2)
RUN curl -fL \
    https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.4-stable.tar.xz \
    -o /tmp/flutter.tar.xz \
    && tar -xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN git config --global --add safe.directory /opt/flutter
WORKDIR /app

COPY pubspec.* ./
RUN flutter --version && dart --version && flutter pub get

COPY . .

RUN flutter build web --release

# Stage 2: Serve using Nginx
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
