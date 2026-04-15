# Estágio 1: Build
FROM --platform=$BUILDPLATFORM node:24-bookworm AS builder

ARG JELLYFIN_WEB_VERSION=master
WORKDIR /app

# Configurações de ambiente para evitar falta de memória (Heap Limit)
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Instalar dependências do sistema necessárias para compilar módulos nativos
RUN apt-get update && apt-get install -y \
    git \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Atualizar o npm para a versão exigida (>= 11.0.0)
RUN npm install -g npm@latest

# Clonar com profundidade 1 para ser mais rápido
RUN git clone --depth 1 --branch ${JELLYFIN_WEB_VERSION} https://github.com/jellyfin/jellyfin-web.git .

# Configurações de rede para o npm ser mais resiliente
RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000

# Usar npm ci para uma instalação limpa e baseada estritamente no lockfile
# Isso evita que o npm tente "resolver" dependências, o que consome muita CPU/RAM
RUN npm ci --include=dev --prefer-offline || npm install --include=dev --no-audit

# Build de produção
RUN npm run build:production

# Estágio 2: Runner (Nginx)
FROM nginx:alpine

ENV PORT=80

# Copiar os arquivos estáticos gerados no estágio de build
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Comando para trocar a porta dinamicamente e iniciar o Nginx
CMD ["sh", "-c", "sed -i \"s/listen 80;/listen ${PORT};/\" /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
