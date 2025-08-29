# AWS Network Module

This Terraform module provisions AWS networking resources such as VPCs, subnets, route tables, security groups, and internet gateways.

## File Structure
- `vpc.tf`: Defines the VPC resource.
- `subnets.tf`: Manages subnet resources.
- `route_tables.tf`: Configures route tables.
- `security_groups.tf`: Sets up security groups.
- `igw.tf`: Provisions the internet gateway.
- `variables.tf`: Declares input variables.
- `outputs.tf`: Exposes resource outputs (e.g., VPC ID, subnet IDs).
- `versions.tf`: Specifies provider and Terraform versions.
- `examples/basic_usage/`: Example usage of the module.

## Usage Example

See `examples/basic_usage/main.tf` for a working example. To use this module:

```hcl
module "network" {
	source = "../../modules/network"
	# Set required variables here
}
```

Run `terraform init` and `terraform apply` in your environment to provision resources.
