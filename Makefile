# Local dev-loop helpers for adb_server.
#
# Intended for running the control-plane server on your Mac (with OrbStack
# providing the Docker engine) while iterating. Deployment to the Synology
# NAS is a separate, manual step (docker-compose.yml + Container Manager --
# see adb_server/README.md).

ADB_SERVER_DIR := adb_server

.PHONY: help build up down restart logs ps test

help:
	@echo "Targets:"
	@echo "  make build    Build the adb_server image"
	@echo "  make up       Start adb_server (builds if needed), detached"
	@echo "  make down     Stop and remove the adb_server container"
	@echo "  make restart  Restart the adb_server container"
	@echo "  make logs     Follow adb_server logs"
	@echo "  make ps       Show adb_server container status"
	@echo "  make test     Run the adb_server Dart test suite locally"

$(ADB_SERVER_DIR)/.env:
	@if [ ! -f $(ADB_SERVER_DIR)/.env ]; then \
		echo "Creating $(ADB_SERVER_DIR)/.env from .env.example -- edit it with your DUT_ADDRESS."; \
		cp $(ADB_SERVER_DIR)/.env.example $(ADB_SERVER_DIR)/.env; \
	fi

build: $(ADB_SERVER_DIR)/.env
	cd $(ADB_SERVER_DIR) && docker compose build

up: $(ADB_SERVER_DIR)/.env
	cd $(ADB_SERVER_DIR) && docker compose up --build -d

down:
	cd $(ADB_SERVER_DIR) && docker compose down

restart: down up

logs:
	cd $(ADB_SERVER_DIR) && docker compose logs -f

ps:
	cd $(ADB_SERVER_DIR) && docker compose ps

test:
	cd $(ADB_SERVER_DIR) && dart test
