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
        libpcre3 \
        libssl3 \
        zlib1g && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/nginx /usr/local/nginx

RUN mkdir -p /var/log/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx.conf /etc/nginx/nginx.conf.template
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1935
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
