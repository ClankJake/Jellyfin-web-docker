# Estágio 1: Build
FROM --platform=$BUILDPLATFORM node:24-bookworm AS builder

ARG JELLYFIN_WEB_VERSION=master
WORKDIR /app

ENV NODE_OPTIONS="--max-old-space-size=4096"

# Instalação de dependências do sistema
RUN apt-get update && apt-get install -y git python3 make g++ && rm -rf /var/lib/apt/lists/*
RUN npm install -g npm@latest

# Clone do repositório oficial do Jellyfin Web
RUN git clone --depth 1 --branch ${JELLYFIN_WEB_VERSION} https://github.com/jellyfin/jellyfin-web.git .

# Configurações de rede para evitar timeouts no npm
RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000

# Instalação de dependências do projeto e Build
RUN npm ci --include=dev --prefer-offline || npm install --include=dev --no-audit
RUN npm run build:production

# Estágio 2: Runner (Servidor Web Nginx)
FROM nginx:alpine

# Copia os arquivos compilados do estágio de build
COPY --from=builder /app/dist /usr/share/nginx/html

# Copia a configuração estática do Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Comando padrão para iniciar o Nginx
CMD ["nginx", "-g", "daemon off;"]
