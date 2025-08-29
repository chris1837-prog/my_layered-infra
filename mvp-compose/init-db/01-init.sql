version: '3.8'

services:
  # ... (seu serviço 'app' permanece o mesmo)

  pgbouncer:
    image: edoburu/pgbouncer:latest
    container_name: pgbouncer
    restart: unless-stopped
    ports:
      - "127.0.0.1:6432:6432"
    depends_on:
      postgres:
        condition: service_healthy
    env_file:
      - .env
    # Adicione este volume para montar o arquivo de configuração do PgBouncer
    volumes:
      - ./pgbouncer/pgbouncer.ini:/etc/pgbouncer/pgbouncer.ini
    environment:
      # Essas variáveis de ambiente são usadas pela imagem para gerar o arquivo de usuário
      - DATABASE_URL=postgres://appuser:mysupersecretpassword@postgres:5432/appdb

  postgres:
    image: postgres:15-alpine
    container_name: pg_db
    restart: unless-stopped
    volumes:
      # Adicione este volume para montar o diretório de inicialização do DB
      - ./data/pg_data:/var/lib/postgresql/data
      - ./db-init:/docker-entrypoint-initdb.d
    env_file:
      - .env
    # ... (o resto da configuração do postgres permanece o mesmo)