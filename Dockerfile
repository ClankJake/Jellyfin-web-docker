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

# Instalar gettext para usar a ferramenta envsubst (manipulação de variáveis no Nginx)
RUN apk add --no-cache gettext

ENV JELLYFIN_SERVER=""
ENV PORT=80

COPY --from=builder /app/dist /usr/share/nginx/html
# Copiamos o ficheiro como um template
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# Script de arranque mágico:
# Preenche o ficheiro Nginx com as portas e IP do backend.
CMD ["sh", "-c", " \
    envsubst '\\$PORT \\$JELLYFIN_SERVER' < /etc/nginx/nginx.conf.template > /etc/nginx/conf.d/default.conf; \
    nginx -g 'daemon off;'"]
