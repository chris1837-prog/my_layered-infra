# AWS Network Module


This Terraform module provisions AWS networking resources for your cloud infrastructure. It is designed to be reusable and composable, allowing you to manage VPCs, subnets, route tables, security groups, and internet gateways in a modular way.

## File Structure

### Directory Tree

```
aws-infra/modules/network/
├── igw.tf
├── outputs.tf
├── README.md
├── route_tables.tf
├── security_groups.tf
├── subnets.tf
├── variables.tf
├── versions.tf
├── vpc.tf
└── examples/           # Internal module test only, not usage examples
	└── basic_usage/
		├── main.tf
		├── outputs.tf
		└── versions.tf
```

- `vpc.tf`: Defines the main Virtual Private Cloud (VPC) resource, including its CIDR block and tags. This is the foundational network component for all other resources.
- `subnets.tf`: Provisions public and private subnets within the VPC. Subnets are configured based on input variables, allowing for flexible network segmentation.
- `route_tables.tf`: Creates and associates route tables for subnets, enabling routing between subnets and to external networks (e.g., internet gateway).
- `security_groups.tf`: Defines security groups to control inbound and outbound traffic for resources within the VPC. Rules can be customized via variables.
- `igw.tf`: Provisions an Internet Gateway and attaches it to the VPC, allowing public subnets to access the internet.
- `variables.tf`: Declares all input variables required by the module, such as CIDR blocks, subnet counts, and tags. Customize these to fit your environment.
- `outputs.tf`: Exposes key resource attributes (e.g., VPC ID, subnet IDs, security group IDs) for use by parent modules or other resources.
- `versions.tf`: Specifies the required Terraform and provider versions to ensure compatibility and reproducibility.
- `examples/basic_usage/`: Internal test configuration for validating the module. Not intended as user documentation or usage example.

## Usage Example


### Basic Usage

See `examples/basic_usage/main.tf` for a complete example. To use this module in your own configuration:

```hcl
module "network" {
	source = "../../modules/network"
	vpc_cidr_block      = "10.0.0.0/16"
	public_subnet_cidrs = ["10.0.1.0/24"]
	private_subnet_cidrs = ["10.0.2.0/24"]
	# Add other required variables as needed
}
```

After configuring your variables, run:

```sh
terraform init
terraform apply
```

This will provision the VPC, subnets, route tables, security groups, and internet gateway as defined in the module.

### Accessing Outputs

You can access outputs from the module in your parent configuration:

```hcl
output "vpc_id" {
	value = module.network.vpc_id
}
```

This allows you to pass network resource IDs to other modules (e.g., EC2, RDS, etc.).

### Customization

Edit `variables.tf` to add or change input variables. Update `outputs.tf` to expose additional resource attributes as needed. You can also modify resource definitions in the respective `.tf` files to fit your requirements.

### Example Directory

**Note:** The `examples/basic_usage/` directory is used only for internal module testing and is not intended as a reference, template, or usage example for users.
