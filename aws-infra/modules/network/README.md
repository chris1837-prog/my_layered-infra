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
├── test/                   # Terratest skeleton for automated testing
│   └──  network_test.go
└── examples/               # Usage examples and module testing
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
- `test/`: Contains a Terratest skeleton for automated testing of the module.
- `examples/basic_usage`: Provides a working example of how to consume this module. You can use it as both a reference for usage and as a way to validate the module with terraform plan/apply.


## Usage

### Basic Usage

```hcl
module "network" {
  source = "./modules/network"

  project_name = "myapp-production"
  cidr_block   = "10.0.0.0/16"
  
  az_configurations = {
    "us-east-1a" = {
      public_subnet_cidr  = "10.0.1.0/24"
      private_subnet_cidr = "10.0.2.0/24"
    }
  }

  common_tags = {
    Environment = "production"
    Project     = "myapp"
  }

  ssh_admin_cidr       = "192.168.1.0/24"
  wireguard_admin_cidr = "10.0.0.0/16"
}
```


## Examples Directory

The `examples/` folder contains runnable configurations that demonstrate how to use this module.

### `basic_usage/`

- A **minimal working example** of the module.  
- Provisions a VPC, subnets, route tables, an internet gateway, and security groups.  
- Serves both as:
  - A **validation test** (`terraform init/validate/plan`)  
  - **Documentation**, showing expected inputs and outputs.  
- You can copy and adapt this configuration as a starting point for your own infrastructure.

### `private_egress_via_edge/`

- An **advanced example** demonstrating cost-effective private subnet internet egress.
- Replaces NAT Gateway with a NAT instance (Edge VM) for significant cost savings.
- Implements the complete architecture:
  - Edge instance with `source_dest_check = false`
  - iptables MASQUERADE rules for the entire VPC CIDR
  - Private route table with default route (0.0.0.0/0) pointing to Edge instance
  - Automated SSH key generation for testing
- Includes comprehensive Terratest that validates:
  - Route table configuration
  - Instance connectivity
  - Actual internet access from private instances

## Testing

### Manual Testing with Examples

#### Basic Validation
```bash
cd examples/basic_usage/
terraform init
terraform validate  # Should pass with zero errors
terraform plan      # Should show only network resources
```

#### NAT Instance Validation
```bash
cd examples/private_egress_via_edge/
terraform init
terraform validate  # Should pass with zero errors
terraform plan      # Should show network resources + NAT instances
```

### Automated Testing with Terratest

#### Basic Infrastructure Tests
```bash
cd test/
go mod init network-test
go mod tidy
go test -v -timeout 30m -run TestNetworkModule .
```

#### NAT Functionality Tests
```bash
cd test/
go test -v -timeout 30m -run TestPrivateEgressViaEdge .
```

The Terratest suite validates:
- **Basic Structure**: VPC creation, subnet counts, security groups existence
- **NAT Functionality**: 
  - Edge instance source/dest check configuration
  - Private route table default route to Edge instance
  - Actual internet access from private instances via SSH testing
  - Comprehensive AWS API validation

**Note**: The NAT test requires SSH connectivity and validates real network traffic flow from private instances to the internet.
```

 You can copy and adapt this configuration as a starting point for your own infrastructure.