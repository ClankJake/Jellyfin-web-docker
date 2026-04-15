# Estágio 1: Build
FROM --platform=$BUILDPLATFORM node:24-bookworm AS builder

ARG JELLYFIN_WEB_VERSION=master
WORKDIR /app

ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN apt-get update && apt-get install -y git python3 make g++ && rm -rf /var/lib/apt/lists/*
RUN npm install -g npm@latest
RUN git clone --depth 1 --branch ${JELLYFIN_WEB_VERSION} https://github.com/jellyfin/jellyfin-web.git .
RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000

RUN npm ci --include=dev --prefer-offline || npm install --include=dev --no-audit
RUN npm run build:production

# Estágio 2: Runner (Nginx)
FROM nginx:alpine

# Instala o JQ no Alpine para manipular o JSON com segurança
RUN apk add --no-cache jq

ENV JELLYFIN_SERVER=""
ENV PORT=80

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Script de inicialização:
# 1. Ajusta a porta do Nginx
# 2. Injeta o servidor padrão e pré-configura a lista de servidores no config.json
CMD ["sh", "-c", " \
    if [ ! -z \"$JELLYFIN_SERVER\" ]; then \
        echo \"Configurando backend automático para: $JELLYFIN_SERVER\"; \
        # Injeta defaultServerAddress e popula a array servers para pular a tela de seleção \
        jq \".defaultServerAddress = \\\"$JELLYFIN_SERVER\\\" | .servers = [{\\\"Name\\\": \\\"Servidor Remoto\\\", \\\"Id\\\": \\\"remote-server\\\", \\\"ManualAddress\\\": \\\"$JELLYFIN_SERVER\\\", \\\"manualAddressOnly\\\": true}]\" /usr/share/nginx/html/config.json > /tmp/config.json && \
        cp /tmp/config.json /usr/share/nginx/html/config.json; \
    fi; \
    sed -i \"s/listen 80;/listen ${PORT};/\" /etc/nginx/conf.d/default.conf && \
    nginx -g 'daemon off;'"]
