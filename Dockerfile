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
# Certifique-se de usar o nginx.conf (sem ser .template)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Script de arranque:
# Injeta um JavaScript inteligente no cabeçalho do index.html.
# Este script:
# 1. Guarda o IP do backend.
# 2. NÃO define um ID (para não disparar o alarme de segurança).
# 3. Limpa rastos de testes anteriores automaticamente.
CMD ["sh", "-c", " \
    if [ ! -z \"$JELLYFIN_SERVER\" ]; then \
        echo \"A configurar backend direto para: $JELLYFIN_SERVER\"; \
        INJECT=\"<script>try{var t='$JELLYFIN_SERVER';if(t){var c=localStorage.getItem('jellyfin_credentials');var p=c?JSON.parse(c):{Servers:[]};var s=p.Servers[0];if(!s||s.ManualAddress!==t||s.Id==='auto-server'||s.Id==='proxy-server'){p.Servers=[{ManualAddress:t,Name:'Jellyfin',manualAddressOnly:true}];localStorage.setItem('jellyfin_credentials',JSON.stringify(p));}}}catch(e){}</script>\"; \
        sed -i \"s|</head>|$INJECT</head>|i\" /usr/share/nginx/html/index.html; \
    fi; \
    sed -i \"s/listen 80;/listen ${PORT};/\" /etc/nginx/conf.d/default.conf && \
    nginx -g 'daemon off;'"]
