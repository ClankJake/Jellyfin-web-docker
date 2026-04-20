# Estágio 1: Build (Compilação do Jellyfin Web)
FROM --platform=$BUILDPLATFORM node:24-bookworm AS builder

ARG JELLYFIN_WEB_VERSION=master
WORKDIR /app

ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN apt-get update && apt-get install -y git python3 make g++ && rm -rf /var/lib/apt/lists/*
RUN npm install -g npm@latest

RUN git clone --depth 1 --branch ${JELLYFIN_WEB_VERSION} https://github.com/jellyfin/jellyfin-web.git .

RUN npm ci --include=dev --prefer-offline || npm install --include=dev --no-audit
RUN npm run build:production

# Estágio 2: Runner (Nginx como Proxy Transparente)
FROM nginx:alpine
RUN apk add --no-cache gettext

ENV JELLYFIN_SERVER=""
ENV PORT=80

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/nginx.conf.template

# O script apenas aplica as variáveis de ambiente no template do Nginx
CMD ["sh", "-c", "envsubst '${JELLYFIN_SERVER} ${PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
