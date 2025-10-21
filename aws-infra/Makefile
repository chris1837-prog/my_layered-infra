.PHONY: help test-tf-policy

# Default environment
ENV ?= dev

# Directories
TF_DIR = environments/$(ENV)
POLICY_DIR ?= aws-infra/policies

# --- HELP SECTION ---
help: ## Show available Makefile targets
	@echo ""
	@echo "Available Makefile commands:"
	@echo "-----------------------------------------------"
	@echo "make test-tf-policy ENV=<env>   Run Terraform policy checks for a specific environment."
	@echo "                                Default: ENV=dev"
	@echo "make help                       Show this help message."
	@echo ""
	@echo "Example usage:"
	@echo "  make test-tf-policy ENV=staging"
	@echo "-----------------------------------------------"

# --- POLICY TEST ---
test-tf-policy: ## Run Terraform plan and conftest policy validation
	@echo " Running Terraform plan and policy check for environment: $(ENV)..."
	@set -e; \
	terraform -chdir=$(TF_DIR) init -input=false >/dev/null; \
	terraform -chdir=$(TF_DIR) plan -out=tfplan.binary >/dev/null; \
	terraform -chdir=$(TF_DIR) show -json tfplan.binary > $(TF_DIR)/tfplan.json; \
	conftest test $(TF_DIR)/tfplan.json -p $(POLICY_DIR); \
	echo " Policy validation passed successfully for environment: $(ENV)"

