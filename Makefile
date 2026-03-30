DOCKER_COMPOSE ?= docker compose
DEVTOOLS_RUN = $(DOCKER_COMPOSE) run --rm devtools

lint:
	$(DEVTOOLS_RUN) ./scripts/lint.sh

format:
	$(DEVTOOLS_RUN) ./scripts/format.sh

devtools-build:
	$(DOCKER_COMPOSE) build devtools

devtools-shell:
	$(DEVTOOLS_RUN) bash
