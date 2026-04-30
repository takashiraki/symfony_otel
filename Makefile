GREEN  := \033[0;32m
RED    := \033[0;31m
BLUE   := \033[0;34m
BOLD   := \033[1m
RESET  := \033[0m

init:
	@echo "Initializing Symfony OTEL project..."
	@echo "Creating proxy network and container..."
	@docker network create my_proxy_network 2>/dev/null && echo "$(GREEN)Network my_proxy_network created$(RESET)" || echo "$(GREEN)Network my_proxy_network already exists, skipping$(RESET)"
	@docker compose -f docker_proxy_network/docker-compose.yml build --no-cache
	@echo "$(GREEN)Proxy network and container are ready$(RESET)"

	@echo "Setting up Symfony application environment variables..."
	@cp -n docker_otel/.env.example docker_otel/.env && echo "$(GREEN)Created docker_otel/.env$(RESET)" || echo "$(GREEN)docker_otel/.env already exists, skipping$(RESET)"
	@for pair in \
		"PROMETHEUS_CONTAINER_NAME=symfony-otel-prometheus" \
		"PROMETHEUS_VIRTUAL_HOST=symfony-otel-prometheus.localhost" \
		"PROMETHEUS_VIRTUAL_PORT=9090" \
		"GRAFANA_CONTAINER_NAME=symfony-otel-grafana" \
		"GRAFANA_VIRTUAL_HOST=symfony-otel-grafana.localhost" \
		"GRAFANA_VIRTUAL_PORT=3000" \
		"TEMPO_CONTAINER_NAME=symfony-otel-tempo" \
		"TEMPO_VIRTUAL_HOST=symfony-otel-tempo.localhost" \
		"TEMPO_VIRTUAL_PORT=3200"; do \
		key=$$(echo $$pair | cut -d= -f1); \
		value=$$(echo $$pair | cut -d= -f2-); \
		sed -i '' "s|^$$key=.*|$$key=$$value|" docker_otel/.env; \
	done
	@echo "$(GREEN)Environment variables set up in docker_otel/.env$(RESET)"
	@sed -i '' "s|http://my-tempo:|http://symfony-otel-tempo:|g" docker_otel/grafana/provisioning/datasources/tempo.yaml && echo "$(GREEN)Updated tempo datasource URL$(RESET)"

	@echo "Setting up Symfony application environment variables..."
	@if [ ! -d symfony/src/my_symfony ]; then \
		git clone -b v0.0.0 https://github.com/takashiraki/my_symfony.git symfony/src/my_symfony && \
		echo "$(GREEN)Cloned symfony$(RESET)"; \
	else \
		echo "$(GREEN)symfony/src/my_symfony already exists, skipping$(RESET)"; \
	fi
	@sed -i '' "s|^OTEL_EXPORTER_OTLP_ENDPOINT=.*|OTEL_EXPORTER_OTLP_ENDPOINT=http://symfony-otel-tempo:4318|" symfony/src/my_symfony/.env.dev && echo "$(GREEN)Updated OTEL_EXPORTER_OTLP_ENDPOINT in .env.dev$(RESET)"
	@sed -i '' "s|SetEnv OTEL_EXPORTER_OTLP_ENDPOINT .*|SetEnv OTEL_EXPORTER_OTLP_ENDPOINT http://symfony-otel-tempo:4318|" symfony/src/my_symfony/.docker/infra/000-default.conf && echo "$(GREEN)Updated OTEL_EXPORTER_OTLP_ENDPOINT in 000-default.conf$(RESET)"

	@cp -n symfony/.env.example symfony/.env && echo "$(GREEN)Created symfony/.env$(RESET)" || echo "$(GREEN)symfony/.env already exists, skipping$(RESET)"
	@for pair in \
		"CONTAINER_NAME=symfony_otel" \
		"REPOSITORY=src/my_symfony" \
		"DOCKER_PATH=src/my_symfony" \
		"VIRTUAL_HOST=symfony-otel.localhost" \
		"TZ=locale" \
		"OTEL_EXPORTER_OTLP_ENDPOINT=http://symfony-otel-tempo:4318" \
		"OTEL_SERVICE_NAME=symfony_otel"; do \
		key=$$(echo $$pair | cut -d= -f1); \
		value=$$(echo $$pair | cut -d= -f2-); \
		sed -i '' "s|^$$key=.*|$$key=$$value|" symfony/.env; \
	done
	@echo "$(GREEN)Environment variables set up in symfony/.env$(RESET)"

	@echo "Building Docker images for Symfony OTEL application..."
	@docker compose -f symfony/docker-compose.yml build --no-cache
	@echo "$(GREEN)Docker images built successfully$(RESET)"

	@printf "\n$(BOLD)$(GREEN)╔════════════════════════════════════════╗$(RESET)\n"
	@printf "$(BOLD)$(GREEN)║   Initialization complete!             ║$(RESET)\n"
	@printf "$(BOLD)$(GREEN)╚════════════════════════════════════════╝$(RESET)\n\n"
	@printf "  $(BLUE)Next step:$(RESET) run $(BOLD)make up$(RESET) to start the application\n\n"

up:
	@echo "Starting Symfony OTEL application..."
	@docker compose -f docker_otel/docker-compose.yml up -d
	@echo "$(GREEN)Symfony OTEL application is starting...$(RESET)"

	@echo "Starting proxy container..."
	@docker compose -f docker_proxy_network/docker-compose.yml up -d
	@echo "$(GREEN)Proxy container is starting...$(RESET)"

	@echo "Starting Symfony application container..."
	@docker compose -f symfony/docker-compose.yml up -d
	@echo "$(GREEN)Symfony application container is starting...$(RESET)"

	@echo "Running composer install..."
	@docker exec symfony_otel composer install && echo "$(GREEN)composer install done$(RESET)"

migrate:
	@echo "Migrating database..."
	@docker exec symfony_otel php bin/console doctrine:migrations:migrate --no-interaction && echo "$(GREEN)Database migrated successfully$(RESET)"

check-deps:
	@echo "Checking dependencies..."
	@command -v docker > /dev/null 2>&1 || (echo "$(RED)Error: docker is not installed$(RESET)" && exit 1)
	@docker compose version > /dev/null 2>&1 || (echo "$(RED)Error: docker compose is not installed$(RESET)" && exit 1)
	@echo "$(GREEN)docker and docker compose are available$(RESET)"

build-tailwind:
	@echo "Building Tailwind CSS assets..."
	@docker exec symfony_otel php bin/console tailwind:build
	@echo "$(GREEN)Tailwind CSS assets built successfully$(RESET)"

quick-setup: check-deps init up build-tailwind migrate
	@printf "\n$(BOLD)$(GREEN)╔════════════════════════════════════════╗$(RESET)\n"
	@printf "$(BOLD)$(GREEN)║   Quick setup complete!                ║$(RESET)\n"
	@printf "$(BOLD)$(GREEN)╚════════════════════════════════════════╝$(RESET)\n\n"
	@printf "  $(BLUE)Your Symfony OTEL application is up and running!$(RESET)\n\n"

down:
	@echo "Stopping Symfony OTEL application..."
	@docker compose -f docker_otel/docker-compose.yml down
	@echo "$(GREEN)Symfony OTEL application stopped$(RESET)"

	@echo "Stopping proxy container..."
	@docker compose -f docker_proxy_network/docker-compose.yml down
	@echo "$(GREEN)Proxy container stopped$(RESET)"

	@echo "Stopping Symfony application container..."
	@docker compose -f symfony/docker-compose.yml down
	@echo "$(GREEN)Symfony application container stopped$(RESET)"