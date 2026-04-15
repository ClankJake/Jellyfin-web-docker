# Estágio 1: Build
FROM node:20-bookworm AS builder

# Argumento para definir a branch ou tag do Jellyfin Web (opcional)
ARG JELLYFIN_WEB_VERSION=master

WORKDIR /app

# Instalar git e clonar o repositório diretamente no build
RUN apt-get update && apt-get install -y git && \
    git clone --depth 1 --branch ${JELLYFIN_WEB_VERSION} https://github.com/jellyfin/jellyfin-web.git .

# Instalar dependências e realizar o build de produção
RUN npm install && npm run build:production

# Estágio 2: Runner (Nginx)
FROM nginx:alpine

# Variável de ambiente para a porta (Padrão 80)
ENV PORT=80

# Copiar os arquivos estáticos
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Script para substituir a porta no arquivo de configuração do Nginx antes de iniciar
CMD ["sh", "-c", "sed -i \"s/listen 80;/listen ${PORT};/\" /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
