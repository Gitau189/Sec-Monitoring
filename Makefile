# =============================================================================
# DSA4030 Group 9 — one-command operations for the team
# =============================================================================
.DEFAULT_GOAL := help
COMPOSE := docker compose
PG := sm_postgres
DB ?= company
# psql inside the container authenticates over the local socket with SCRAM,
# so credentials are required even for docker exec.
PGENV := -e PGPASSWORD=postgres

.PHONY: help data up down restart load logs psql tests revert status clean nuke

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

data: ## Generate the 320k-record dataset (CSV)
	python3 data/generate_data.py

up: ## Build + start the whole stack
	$(COMPOSE) up -d --build
	@echo "Grafana: http://localhost:3000 (admin/admin)  Prometheus: http://localhost:9090"

down: ## Stop the stack (keeps data)
	$(COMPOSE) down

restart: ## Restart all services
	$(COMPOSE) restart

load: ## Load generated CSVs into PostgreSQL
	docker exec -i $(PGENV) $(PG) psql -U postgres -d $(DB) < data/load_data.sql

logs: ## Tail PostgreSQL (audit) logs
	docker exec $(PG) tail -f /var/log/postgresql/postgresql.log

psql: ## Open a psql shell as the superuser
	docker exec -it $(PGENV) $(PG) psql -U postgres -d $(DB)

tests: ## Run all six security tests (Part D)
	./tests/security_tests.sh all

revert: ## Undo test-3 privilege escalation
	./tests/security_tests.sh revert

status: ## Show container status
	$(COMPOSE) ps

clean: ## Stop stack + remove generated CSVs
	$(COMPOSE) down
	rm -f data/generated/*.csv

nuke: ## Stop stack + delete ALL volumes (fresh start)
	$(COMPOSE) down -v
