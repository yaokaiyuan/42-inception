.PHONY: all build up down clean

COMPOSE = docker compose
SRC = srcs

all: build up

build:
	@echo "Building images..."
	mkdir -p /home/ykai-yua/data/mariadb
	mkdir -p /home/ykai-yua/data/wordpress
	cd $(SRC) && $(COMPOSE) build --no-cache

up:
	@echo "Starting containers..."
	cd $(SRC) && $(COMPOSE) up -d

down:
	cd $(SRC) && $(COMPOSE) down

clean:
	@echo "Stopping and removing containers and images..."
	cd $(SRC) && $(COMPOSE) down --rmi all -v --remove-orphans

fclean: clean
	@echo "Removing host data directories..."
	rm -rf $(MARIADB_DIR) $(WORDPRESS_DIR)

re: fclean all
