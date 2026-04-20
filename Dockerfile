# Estágio 1: Build (Mantemos igual para gerar os ficheiros)
FROM --platform=$BUILDPLATFORM node:24-bookworm AS builder
ARG JELLYFIN_WEB_VERSION=master
WORKDIR /app
RUN apt-get update && apt-get install -y git python3 make g++ && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${JELLYFIN_WEB_VERSION} https://github.com/jellyfin/jellyfin-web.git .
RUN npm ci --include=dev --prefer-offline
RUN npm run build:production

# Estágio 2: Runner
FROM nginx:alpine
RUN apk add --no-cache gettext

ENV JELLYFIN_SERVER=""
ENV PORT=80

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf.template

# O script substitui o backend no template e arranca o Nginx
CMD ["sh", "-c", "envsubst '${JELLYFIN_SERVER}' < /etc/nginx/nginx.conf.template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
