# Estágio 1: Build
FROM --platform=$BUILDPLATFORM node:20-bookworm AS builder

ARG JELLYFIN_WEB_VERSION=master
WORKDIR /app

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y git python3 make g++ && rm -rf /var/lib/apt/lists/*

# Clonar com profundidade 1 para ser mais rápido
RUN git clone --depth 1 --branch ${JELLYFIN_WEB_VERSION} https://github.com/jellyfin/jellyfin-web.git .

# Configurações para evitar erro de memória e timeout no npm install
# O parâmetro --network-timeout ajuda em conexões instáveis no runner
RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000

# Instalação com flags de performance
RUN npm install --include=dev --prefer-offline --no-audit

# Build de produção
RUN npm run build:production

# Estágio 2: Runner (Nginx)
FROM nginx:alpine

ENV PORT=80
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Comando para trocar a porta dinamicamente
CMD ["sh", "-c", "sed -i \"s/listen 80;/listen ${PORT};/\" /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
