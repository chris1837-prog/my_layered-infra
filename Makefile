# ========================
# Makefile for Local Development (Squad J)
# ========================

# Variables
COMPOSE := docker compose -f mvp-compose/docker-compose.yml
SERVICE_APP := app            # Name of the app service from docker-compose.yml
SERVICE_DB := postgres        # Name of the database service from docker-compose.yml
DB_USER := myuser             # from POSTGRES_USER
DB_NAME := myapp              # from POSTGRES_DB

.PHONY: up down logs test psql help

# ========================
# Targets (Commands)
# ========================

## Display available make commands
help:
	@echo ""
	@echo "🧭  Makefile Commands for Local Development"
	@echo "-------------------------------------------"
	@echo "make up      - Start containers (with build)"
	@echo "make down    - Stop and remove containers"
	@echo "make logs    - View running logs"
	@echo "make test    - Run tests in the app container"
	@echo "make psql    - Open PostgreSQL shell"
	@echo "make help    - Show this help menu"
	@echo ""

## Start all containers in the background (build if needed)
up:
	$(COMPOSE) up -d --build

## Stop and remove all containers
down:
	$(COMPOSE) down

## Show running logs (press Ctrl+C to stop)
logs:
	$(COMPOSE) logs -f || true

## Run tests inside the app container
test:
	$(COMPOSE) exec $(SERVICE_APP) npm test

## Open a PostgreSQL shell in the database container
psql:
	$(COMPOSE) exec $(SERVICE_DB) psql -U $(DB_USER) -d $(DB_NAME)




