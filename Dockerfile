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

# Variáveis de ambiente para o servidor e o ID opcional
ENV JELLYFIN_SERVER=""
ENV JELLYFIN_ID=""
ENV PORT=80

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Script de arranque:
# 1. Injeta o script JS que configura o localStorage.
# 2. Se JELLYFIN_ID for fornecido, ele é incluído para evitar o erro de incompatibilidade.
# 3. O script limpa o cache antigo caso os dados mudem.
CMD ["sh", "-c", " \
    if [ ! -z \"$JELLYFIN_SERVER\" ]; then \
        echo \"Configurando servidor: $JELLYFIN_SERVER (ID: ${JELLYFIN_ID:-auto})\"; \
        export JS_INJECT=\"<script>(function(){try{var u='$JELLYFIN_SERVER',i='$JELLYFIN_ID';var s=localStorage.getItem('jellyfin_credentials');var n=true;if(s){var p=JSON.parse(s);if(p.Servers&&p.Servers[0]&&p.Servers[0].ManualAddress===u&&(i===''||p.Servers[0].Id===i))n=false;}if(n){var o={ManualAddress:u,Name:'Jellyfin',manualAddressOnly:true};if(i)o.Id=i;localStorage.setItem('jellyfin_credentials',JSON.stringify({Servers:[o]}));localStorage.removeItem('active_server_id');location.reload();}}catch(e){}})();</script>\"; \
        sed -i \"s#</head>#$JS_INJECT</head>#\" /usr/share/nginx/html/index.html; \
    fi; \
    sed -i \"s/listen 80;/listen ${PORT};/\" /etc/nginx/conf.d/default.conf && \
    nginx -g 'daemon off;'"]
