FROM buildpack-deps:bookworm AS builder

ARG NGINX_VERSION=1.24.0
ARG NGINX_RTMP_MODULE_VERSION=1.2.2

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libpcre3-dev \
        libssl-dev \
        zlib1g-dev \
        wget && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/build

RUN wget -q https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar xzf nginx-${NGINX_VERSION}.tar.gz && \
    wget -q https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    tar xzf v${NGINX_RTMP_MODULE_VERSION}.tar.gz

RUN cd nginx-${NGINX_VERSION} && \
    ./configure \
        --prefix=/usr/local/nginx \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --add-module=/tmp/build/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} && \
    make -j$(nproc) && \
    make install


FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gettext-base \
        ffmpeg \
        wget \
        libpcre3 \
        libssl3 \
        zlib1g \
        tzdata && \
    rm -rf /var/lib/apt/lists/*

# Set timezone to Pacific Time so placeholder shows PT clock
ENV TZ=America/Los_Angeles

COPY --from=builder /usr/local/nginx /usr/local/nginx

# Prefer IPv4 over IPv6 to avoid "Network is unreachable" errors
# when pushing to services like Facebook that resolve to IPv6 addresses
# but the container lacks IPv6 connectivity
RUN echo "precedence ::ffff:0:0/96 100" >> /etc/gai.conf

RUN mkdir -p /var/log/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Placeholder video resolution and FPS defaults (used at runtime by start_placeholder.sh)
ENV PLACEHOLDER_WIDTH=3840
ENV PLACEHOLDER_HEIGHT=2160
ENV PLACEHOLDER_FPS=60

COPY nginx.conf /etc/nginx/nginx.conf.template
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/on_publish.sh /scripts/on_publish.sh
COPY scripts/on_publish_done.sh /scripts/on_publish_done.sh
COPY scripts/start_placeholder.sh /scripts/start_placeholder.sh
COPY scripts/stop_placeholder.sh /scripts/stop_placeholder.sh
RUN chmod +x /entrypoint.sh /scripts/*.sh

EXPOSE 1935
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
