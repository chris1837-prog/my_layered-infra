.PHONY: test-tf-policy

test-tf-policy:
	@echo "Running Terraform plan and policy check..."
	terraform init -input=false
	terraform plan -out=tfplan.binary
	terraform show -json tfplan.binary > tfplan.json
	conftest test tfplan.json -p policies/


