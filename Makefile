# Grounds Development Infrastructure (grounds-dev) Makefile
# Automation for local Kubernetes development environment
# Provides one-command setup and management of k3d cluster with PostgreSQL, Agones, and Open Match

SHELL := /usr/bin/env bash

# Colors for fancy output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
PURPLE := \033[0;35m
CYAN := \033[0;36m
WHITE := \033[1;37m
NC := \033[0m

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help: ## Show this help message
	@echo -e "$(WHITE)Grounds Development Infrastructure (grounds-dev) - Local Kubernetes Development Environment$(NC)"
	@echo -e "$(CYAN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Prerequisites installation
.PHONY: install-prereqs
install-prereqs: ## Install missing prerequisites
	@echo -e "$(BLUE)ℹ️  Checking and installing prerequisites...$(NC)"
	@./scripts/install-prereqs.sh

# Main targets
.PHONY: up
up: install-prereqs ## Start the complete development environment
	@echo -e "$(PURPLE)🚀 Starting Grounds Development Infrastructure environment...$(NC)"
	@echo -e "$(BLUE)ℹ️  Creating k3d cluster and deploying services$(NC)"
	@./cluster/bootstrap.sh
	@echo -e "$(BLUE)ℹ️  Deploying Helm releases...$(NC)"
	@helmfile sync
	@echo -e "$(BLUE)ℹ️  Deploying dummy HTTP server...$(NC)"
	@kubectl apply -f manifests/dummy-http-server.yaml
	@echo -e "$(BLUE)ℹ️  Waiting for Agones CRDs...$(NC)"
	@./scripts/wait-for-crds.sh
	@echo -e "$(BLUE)ℹ️  Deploying Keycloak...$(NC)"
	@$(MAKE) deploy-keycloak
	@echo -e "$(GREEN)✅ Grounds Development Infrastructure environment is ready!$(NC)"
	@echo -e "$(CYAN)📊 Run 'make status' to check deployment status$(NC)"
	@echo -e "$(CYAN)🌐 Access dummy server at: http://localhost/demo$(NC)"

.PHONY: down
down: ## Stop and delete the development environment
	@echo -e "$(YELLOW)⚠️  Stopping Grounds Development Infrastructure environment...$(NC)"
	@k3d cluster delete dev || true
	@echo -e "$(GREEN)✅ Grounds Development Infrastructure environment stopped$(NC)"

.PHONY: reset
reset: down up ## Clean teardown and fresh setup
	@echo -e "$(GREEN)✅ Environment reset completed$(NC)"

.PHONY: status
status: ## Show cluster and deployment status
	@echo -e "$(PURPLE)📊 Cluster Status$(NC)"
	@echo -e "$(CYAN)Nodes:$(NC)"
	@kubectl get nodes
	@echo -e "\n$(CYAN)Pods by namespace:$(NC)"
	@kubectl get pods -A
	@echo -e "\n$(CYAN)Services:$(NC)"
	@kubectl get services -A
	@echo -e "\n$(CYAN)Ingress:$(NC)"
	@kubectl get ingress -A

.PHONY: logs
logs: ## Show logs for all services
	@echo -e "$(PURPLE)📋 Service Logs$(NC)"
	@echo -e "$(CYAN)PostgreSQL logs:$(NC)"
	@kubectl logs -n databases -l app.kubernetes.io/name=postgresql --tail=20 || true
	@echo -e "\n$(CYAN)Agones logs:$(NC)"
	@kubectl logs -n games -l app.kubernetes.io/name=agones --tail=20 || true
	@echo -e "\n$(CYAN)Dummy HTTP Server logs:$(NC)"
	@kubectl logs -n infra -l app=dummy-http-server --tail=20 || true
	@echo -e "\n$(CYAN)Keycloak logs:$(NC)"
	@kubectl logs -n keycloak -l app=keycloak --tail=20 || true

.PHONY: port-forward
port-forward: ## Port forward services to localhost
	@echo -e "$(BLUE)ℹ️  Port forwarding services...$(NC)"
	@echo -e "$(CYAN)PostgreSQL: localhost:5432$(NC)"
	@echo -e "$(CYAN)Dummy HTTP Server: localhost:8080$(NC)"
	@echo -e "$(YELLOW)⚠️  Run in separate terminals:$(NC)"
	@echo -e "$(WHITE)kubectl port-forward -n databases svc/postgresql 5432:5432$(NC)"
	@echo -e "$(WHITE)kubectl port-forward -n infra svc/dummy-http-server 8080:80$(NC)"

.PHONY: clean
clean: ## Clean up all resources
	@echo -e "$(YELLOW)⚠️  Cleaning up all resources...$(NC)"
	@k3d cluster delete dev || true
	@rm -f kubeconfig || true
	@if [ -f ~/.kube/config ]; then \
		echo -e "$(BLUE)ℹ️  Cleaning k3d-dev from ~/.kube/config...$(NC)"; \
		kubectl config delete-context k3d-dev || true; \
		kubectl config delete-cluster k3d-dev || true; \
		kubectl config delete-user admin@k3d-dev || true; \
		echo -e "$(GREEN)✅ k3d-dev context removed from ~/.kube/config$(NC)"; \
	fi
	@echo -e "$(GREEN)✅ Cleanup completed$(NC)"

.PHONY: test
test: ## Test the deployment
	@echo -e "$(PURPLE)🧪 Testing deployment...$(NC)"
	@echo -e "$(BLUE)ℹ️  Testing cluster connectivity...$(NC)"
	@kubectl cluster-info
	@echo -e "$(BLUE)ℹ️  Testing dummy HTTP server...$(NC)"
	@curl -s http://localhost/demo || echo -e "$(YELLOW)⚠️  Dummy server not accessible (may still be starting)$(NC)"
	@echo -e "$(GREEN)✅ Tests completed$(NC)"

# Utility targets
.PHONY: check-prereqs
check-prereqs: ## Check prerequisites
	@echo -e "$(BLUE)ℹ️  Checking prerequisites...$(NC)"
	@./scripts/install-prereqs.sh --check-only || true

.PHONY: export-kubeconfig
export-kubeconfig: ## Export k3d cluster kubeconfig to ./kubeconfig
	@echo -e "$(BLUE)ℹ️  Exporting kubeconfig...$(NC)"
	@k3d kubeconfig get dev > kubeconfig
	@echo -e "$(GREEN)✅ Kubeconfig exported to ./kubeconfig$(NC)"
	@echo -e "$(CYAN)Use it with: export KUBECONFIG=\$$(pwd)/kubeconfig$(NC)"

.PHONY: deploy-keycloak
deploy-keycloak: ## Deploy Keycloak operator and instance
	@./scripts/deploy-keycloak.sh
