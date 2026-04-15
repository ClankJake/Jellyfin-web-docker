# Estágio 1: Build
FROM --platform=$BUILDPLATFORM node:24-bookworm AS builder

ARG JELLYFIN_WEB_VERSION=master
WORKDIR /app

ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN apt-get update && apt-get install -y git python3 make g++ jq && rm -rf /var/lib/apt/lists/*

RUN npm install -g npm@latest

RUN git clone --depth 1 --branch ${JELLYFIN_WEB_VERSION} https://github.com/jellyfin/jellyfin-web.git .

RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000

RUN npm ci --include=dev --prefer-offline || npm install --include=dev --no-audit

RUN npm run build:production

# Estágio 2: Runner (Nginx)
FROM nginx:alpine

ENV JELLYFIN_SERVER=""
ENV PORT=80

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Script de inicialização aprimorado
# 1. Substitui a porta no Nginx
# 2. Cria/Injeta o servidor padrão no config.json de forma robusta usando jq
CMD ["sh", "-c", " \
    if [ ! -z \"$JELLYFIN_SERVER\" ]; then \
        echo \"Configurando servidor padrão para: $JELLYFIN_SERVER\"; \
        # Usa jq para garantir que a chave existe no JSON de forma válida \
        jq \".defaultServerAddress = \\\"$JELLYFIN_SERVER\\\"\" /usr/share/nginx/html/config.json > /tmp/config.json && \
        cp /tmp/config.json /usr/share/nginx/html/config.json; \
    fi; \
    sed -i \"s/listen 80;/listen ${PORT};/\" /etc/nginx/conf.d/default.conf && \
    nginx -g 'daemon off;'"]
