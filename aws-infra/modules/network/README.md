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
├── test/                   # Terratest automated tests
│   ├── helpers.go
│   ├── basic_usage_test.go
│   └── private_egress_via_edge_test.go
└── examples/               # Usage examples and module testing
    ├── basic_usage/
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── versions.tf
    └── private_egress_via_edge/
        ├── templates
        │   └── edge_init.sh.tftpl
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
- `test/`: Terratest automated tests for infrastructure and network validation.
- `examples/`: Runnable configurations demonstrating module usage. You can use it as both a reference for usage and as a way to validate the module with terraform plan/apply.


## Usage

### Basic Usage

```hcl
# Provider config without a specific profile to use default auth chain
provider "aws" {
  region = "eu-central-1"
}

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

module "network" {
  source = "./modules/network"

  project_name = "layered-infra-test"
  common_tags = {
    Project     = "layered-infra"
    ManagedBy   = "Terraform"
    Environment = "Testing"
    Team        = "A"
    Module      = "Network"
  }

  vpc_cidr           = "10.0.0.0/16"
  allowed_admin_cidrs = ["10.0.0.0/8"] 
  
  az_configurations = {
    (data.aws_availability_zones.available.names[0]) = {
      public_subnet_cidr  = "10.0.1.0/24" 
      private_subnet_cidr = "10.0.2.0/24" 
    }
  }
  # Optional: Set other variables with their defaults for clarity
  enable_dns_support            = true
  enable_dns_hostnames          = true
  allow_map_public_ip_on_launch = true
  application_port              = 3000
  open_internet_cidr            = "0.0.0.0/0"
  tcp_protocol                  = "tcp"
  udp_protocol                  = "udp"
  all_protocols                 = "-1"
  https_port                    = 443
  http_port                     = 80
  ssh_port                      = 22
  wireguard_port                = 51820
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
  - iptables MASQUERADE rules applied via a user data template 
    (templates/edge_init.sh.tftpl)
  - Private route table with default route (0.0.0.0/0) pointing to Edge instance
  - Automated SSH key generation for testing
  - Temporary security group ingress rule allowing SSH from Edge SG → App SG 
    (for test purposes only)
- Example is kept clean by rendering user_data with templatefile().
- Includes comprehensive Terratest that validates:
  - Route table configuration
  - Instance connectivity
  - Private instance internet access via Edge instance 
    (using real HTTPS request to GitHub API)

## Testing

### Prerequisites

- Go installed (v1.20+ recommended)
- go mod initialized in test/ folder
- SSH private key output from Terraform accessible

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
go mod init basic_usage_test
go mod tidy
go test -v -timeout 30m -run TestNetworkModule .
```

#### NAT Functionality Tests
```bash
cd test/
go mod init private_egress_via_edge_test
go mod tidy
go test -v -timeout 30m -run TestPrivateEgressHTTPS .
```

The Terratest suite validates:
- **Basic Structure**: VPC creation, subnet counts, security groups existence
- **NAT Functionality**: 
  - Edge instance configured with **source_dest_check = false**
  - Private route table default route to Edge instance
  - Private EC2 instance can reach the internet via Edge NAT 
    (validated by curl https://api.github.com)

**Note**: 
- The NAT test requires SSH connectivity and validates real network traffic flow from private instances to the internet.
- SSH access from Edge → Private is enabled only for test automation and should not be used in production.
- In real setups, prefer SSM Session Manager instead of SSH chaining.
```

 You can copy and adapt this configuration as a starting point for your own infrastructure.