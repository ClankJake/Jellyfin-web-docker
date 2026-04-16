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

# Estágio 2: Runner (Nginx estático)
FROM nginx:alpine

ENV JELLYFIN_SERVER=""
ENV PORT=80

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Script de arranque:
# 1. Utilizamos printf para evitar problemas de escape de caracteres no shell.
# 2. Injetamos o script diretamente antes da tag de fechamento do head.
# 3. O código JS verifica se o servidor já está configurado para evitar loops de reload.
CMD ["sh", "-c", " \
    if [ ! -z \"$JELLYFIN_SERVER\" ]; then \
        echo \"Configurando servidor: $JELLYFIN_SERVER\"; \
        export JS_INJECT=\"<script>(function(){try{var u='$JELLYFIN_SERVER';var s=localStorage.getItem('jellyfin_credentials');var n=true;if(s){var p=JSON.parse(s);if(p.Servers&&p.Servers[0]&&p.Servers[0].ManualAddress===u)n=false;}if(n){localStorage.setItem('jellyfin_credentials',JSON.stringify({Servers:[{ManualAddress:u,Name:'Jellyfin',manualAddressOnly:true}]}));localStorage.removeItem('active_server_id');location.reload();}}catch(e){}})();</script>\"; \
        sed -i \"s#</head>#$JS_INJECT</head>#\" /usr/share/nginx/html/index.html; \
    fi; \
    sed -i \"s/listen 80;/listen ${PORT};/\" /etc/nginx/conf.d/default.conf && \
    nginx -g 'daemon off;'"]
