.PHONY: test-tf-policy

# Default Terraform directory
TF_DIR ?= aws-infra/environments/dev
POLICY_DIR ?= aws-infra/policies

test-tf-policy:
	@echo "Running Terraform plan and policy check in $(TF_DIR)..."
	@set -e; \
	terraform -chdir=$(TF_DIR) init -input=false >/dev/null; \
	terraform -chdir=$(TF_DIR) plan -out=tfplan.binary >/dev/null; \
	terraform -chdir=$(TF_DIR) show -json tfplan.binary > $(TF_DIR)/tfplan.json; \
	conftest test $(TF_DIR)/tfplan.json -p $(POLICY_DIR); \
	echo "✅ Policy validation passed successfully."



