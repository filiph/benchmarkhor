# Local dev-loop helpers for adb_server.
#
# Intended for running the control-plane server on your Mac (with OrbStack
# providing the Docker engine) while iterating. Deployment to the Synology
# NAS is a separate, manual step (docker-compose.yml + Container Manager --
# see adb_server/README.md).

ADB_SERVER_DIR := adb_server
IMAGE_NAME := ghcr.io/filiph/adb_server
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DIRTY := $(shell git status --porcelain 2>/dev/null)
ifneq ($(DIRTY),)
	GIT_COMMIT := $(GIT_COMMIT)-dirty
endif

.PHONY: help build up down restart logs ps test push export

help:
	@echo "Targets:"
	@echo "  make build    Build the adb_server image"
	@echo "  make up       Start adb_server (builds if needed), detached"
	@echo "  make down     Stop and remove the adb_server container"
	@echo "  make restart  Restart the adb_server container"
	@echo "  make logs     Follow adb_server logs"
	@echo "  make ps       Show adb_server container status"
	@echo "  make push     Push container to GHCR"
	@echo "  make export   Export image to .tar file for manual NAS upload"
	@echo "  make test     Run the adb_server Dart test suite locally"

$(ADB_SERVER_DIR)/.env:
	@if [ ! -f $(ADB_SERVER_DIR)/.env ]; then \
		echo "Creating $(ADB_SERVER_DIR)/.env from .env.example -- edit it with your DUT_ADDRESS."; \
		cp $(ADB_SERVER_DIR)/.env.example $(ADB_SERVER_DIR)/.env; \
	fi

build: $(ADB_SERVER_DIR)/.env
	cd $(ADB_SERVER_DIR) && docker compose build --build-arg GIT_COMMIT=$(GIT_COMMIT)

up: $(ADB_SERVER_DIR)/.env
	cd $(ADB_SERVER_DIR) && GIT_COMMIT=$(GIT_COMMIT) docker compose up --build -d

down:
	cd $(ADB_SERVER_DIR) && docker compose down

restart: down up

logs:
	cd $(ADB_SERVER_DIR) && docker compose logs -f

ps:
	cd $(ADB_SERVER_DIR) && docker compose ps

test:
	cd $(ADB_SERVER_DIR) && dart test

push: $(ADB_SERVER_DIR)/.env
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_NAME):latest --push --build-arg GIT_COMMIT=$(GIT_COMMIT) $(ADB_SERVER_DIR)

# Exports the image for manual upload to Synology (no registry needed).
# Default to amd64 (Intel NAS). Use PLATFORM=linux/arm64 for ARM-based NAS.
PLATFORM ?= linux/amd64
export: $(ADB_SERVER_DIR)/.env
	docker buildx build --platform $(PLATFORM) -t $(IMAGE_NAME):latest --load --build-arg GIT_COMMIT=$(GIT_COMMIT) $(ADB_SERVER_DIR)
	docker save -o adb_server.tar $(IMAGE_NAME):latest
	@echo "Done! Upload 'adb_server.tar' to Synology Container Manager > Image > Add > From file."
