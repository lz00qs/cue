FROM ubuntu:24.04 AS build

ARG FLUTTER_VERSION=3.47.5
ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_ROOT=/opt/flutter \
    PUB_CACHE=/opt/pub-cache \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/pub-cache/bin:$PATH

RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git "$FLUTTER_ROOT" \
    && flutter config --enable-web \
    && flutter precache --web

WORKDIR /app

# Resolve dependencies separately so application-only changes keep this layer.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --verbose

COPY analysis_options.yaml l10n.yaml ./
COPY assets ./assets
COPY lib ./lib
COPY web ./web
RUN flutter build web --release

FROM nginx:1.27-alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
