# Simple Makefile for local development

COMPOSE = docker compose
APP_SERVICE = app
DB_SERVICE = db

# Start all containers
up:
	$(COMPOSE) up -d --build

# Stop and remove containers
down:
	$(COMPOSE) down --volumes --remove-orphans

# Show logs for app service
logs:
	$(COMPOSE) logs -f $(APP_SERVICE)

# Run tests (change pytest to npm test if Node)
test:
	$(COMPOSE) run --rm $(APP_SERVICE) pytest

# Open PostgreSQL shell
psql:
	$(COMPOSE) exec $(DB_SERVICE) psql -U postgres
