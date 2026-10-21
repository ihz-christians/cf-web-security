# ------------------------------------------------------------------------------
# Golden Phat: Project Automation
# ------------------------------------------------------------------------------

IMAGE_NAME := cf-web-api-security
IMAGE_TAG  := latest

.PHONY: help build build-image run interactive clean wordlists

help: ## Display this help message
	@echo "Usage: make <target> [vars]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Variables:"
	@echo "  TARGET  Target identifier for scans (e.g., 'example.com')"
	@echo "  CMD     Command to execute inside the container (e.g., 'nuclei ...')"

build: ## Build the container image from source
	podman build -t $(IMAGE_NAME):$(IMAGE_TAG) -f Containerfile .

build-image: build ## Alias for build


run: ## Execute a command in a target-scoped container
	@if [ -z "$(TARGET)" ] || [ -z "$(CMD)" ]; then \
		echo "Error: TARGET and CMD are required."; \
		echo "Usage: make run TARGET=example.com CMD='subfinder -d example.com'"; \
		exit 1; \
	fi
	./podman-run.sh "$(TARGET)" /bin/bash -lc "$(CMD)"

interactive: ## Start an interactive shell (optional: TARGET=...)
	./podman-interactive.sh "$(TARGET)"

clean: ## Remove the local container image
	podman rmi $(IMAGE_NAME):$(IMAGE_TAG) || true

wordlists: ## Download SecLists to pentest/wordlists
	@echo "[+] Downloading SecLists..."
	@mkdir -p pentest/wordlists
	@if [ ! -d "pentest/wordlists/SecLists" ]; then \
		git clone --depth 1 https://github.com/danielmiessler/SecLists.git pentest/wordlists/SecLists; \
	else \
		echo "[!] SecLists already exists in pentest/wordlists/SecLists"; \
	fi
