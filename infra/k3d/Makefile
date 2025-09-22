SHELL := /usr/bin/bash
.ONESHELL:
.DEFAULT_GOAL := help
.PHONY: help deps up down status test generate-passwords

ifneq ("$(wildcard .env)","")
  include .env
  export
endif

help: ## Lista comandos
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# Comandos básicos
deps: ## Verifica dependências (docker, k3d, kubectl, helm)
	./scripts/install-deps.sh

up: ## Cria o cluster k3d (80/443 expostas) e registry local
	./scripts/create-cluster.sh

down: ## Remove cluster e registry
	./scripts/delete-cluster.sh

status: ## Mostra status do cluster
	./scripts/status.sh


generate-passwords: ## Gera senhas seguras automaticamente
	./scripts/generate-passwords.sh



# Comandos de conveniência
test: ## Testa conectividade do cluster
	./scripts/test-cluster.sh
