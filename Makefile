.PHONY: all build up down clean

COMPOSE = docker compose
SRC = srcs

all: build up

build:
	@echo "Building images..."
	cd $(SRC) && $(COMPOSE) build --no-cache

up:
	@echo "Starting containers..."
	cd $(SRC) && $(COMPOSE) up -d

down:
	cd $(SRC) && $(COMPOSE) down

clean:
	@echo "Stopping and removing containers and images..."
	cd $(SRC) && $(COMPOSE) down --rmi all -v --remove-orphans
