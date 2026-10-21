# ------------------------------------------------------------------------------
# Projektbefehle
# ------------------------------------------------------------------------------

IMAGE_NAME := cf-web-api-security
IMAGE_TAG  := latest

.PHONY: help build build-image run interactive clean wordlists

help: ## Diese Hilfe anzeigen
	@echo "Verwendung: make <Ziel> [Variablen]"
	@echo ""
	@echo "Ziele:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Variablen:"
	@echo "  TARGET  Zielkennung für die Prüfung (z. B. 'example.com')"
	@echo "  CMD     Im Container auszuführender Befehl (z. B. 'nuclei ...')"

build: ## Container-Image bauen
	podman build -t $(IMAGE_NAME):$(IMAGE_TAG) -f Containerfile .

build-image: build ## Alias für build


run: ## Befehl im Container mit Zielkennung ausführen
	@if [ -z "$(TARGET)" ] || [ -z "$(CMD)" ]; then \
		echo "Fehler: TARGET und CMD müssen angegeben werden."; \
		echo "Verwendung: make run TARGET=example.com CMD='subfinder -d example.com'"; \
		exit 1; \
	fi
	./podman-run.sh "$(TARGET)" /bin/bash -lc "$(CMD)"

interactive: ## Interaktive Shell starten (optional: TARGET=...)
	./podman-interactive.sh "$(TARGET)"

clean: ## Lokales Container-Image entfernen
	podman rmi $(IMAGE_NAME):$(IMAGE_TAG) || true

wordlists: ## SecLists-Wortlisten nach pentest/wordlists laden
	@echo "[+] SecLists-Wortlisten werden geladen..."
	@mkdir -p pentest/wordlists
	@if [ ! -d "pentest/wordlists/SecLists" ]; then \
		git clone --depth 1 https://github.com/danielmiessler/SecLists.git pentest/wordlists/SecLists; \
	else \
		echo "[!] SecLists ist bereits unter pentest/wordlists/SecLists vorhanden."; \
	fi
