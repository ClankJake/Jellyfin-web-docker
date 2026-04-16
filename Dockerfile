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
# Este script injeta um JS que força o servidor no localStorage.
# Se você conseguir o ID em /System/Info/Public, substitua o 'manual-id' abaixo.
# Caso contrário, deixamos o Id vazio para ele auto-detectar sem erro de conflito.
CMD ["sh", "-c", " \
    if [ ! -z \"$JELLYFIN_SERVER\" ]; then \
        echo \"A configurar backend direto para: $JELLYFIN_SERVER\"; \
        INJECT=\"<script>\
        (function(){\
            try {\
                var url = '$JELLYFIN_SERVER';\
                var config = {\
                    Servers: [{\
                        ManualAddress: url,\
                        Name: 'Jellyfin',\
                        manualAddressOnly: true\
                    }]\
                };\
                var stored = localStorage.getItem('jellyfin_credentials');\
                var needsUpdate = true;\
                if (stored) {\
                    var parsed = JSON.parse(stored);\
                    if (parsed.Servers && parsed.Servers.length > 0 && parsed.Servers[0].ManualAddress === url) {\
                        needsUpdate = false;\
                    }\
                }\
                if (needsUpdate) {\
                    localStorage.setItem('jellyfin_credentials', JSON.stringify(config));\
                    localStorage.setItem('active_server_id', '');\
                    console.log('Servidor configurado automaticamente');\
                }\
            } catch (e) { console.error(e); }\
        })();\
        </script>\";\
        sed -i \"s|</head>|$INJECT</head>|i\" /usr/share/nginx/html/index.html; \
    fi; \
    sed -i \"s/listen 80;/listen ${PORT};/\" /etc/nginx/conf.d/default.conf && \
    nginx -g 'daemon off;'"]
