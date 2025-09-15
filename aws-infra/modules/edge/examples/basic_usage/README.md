# Edge Module for NAT, WireGuard, and Caddy

This module provisions a secure Edge VM on AWS, providing NAT, WireGuard VPN, and Caddy reverse proxy. It is designed for platform and network engineers to enable secure ingress/egress and VPN access, with all key management and service configuration handled automatically.

## Features
- Provisions an Ubuntu EC2 instance as an Edge VM
- Installs and configures NAT (iptables), WireGuard VPN, and Caddy reverse proxy via cloud-init
- Dynamically generates an SSH key pair (no manual key management)
- Assigns an Elastic IP for stable public access
- Configurable via variables for VPC, subnet, admin CIDRs, backend servers, and domain
- Outputs the public IP, instance ID, and local path to the generated private key

## Usage

```
module "edge" {
	source           = "../../modules/edge"
	project_name     = "mvp"
	environment      = "qa"
	vpc_id           = var.vpc_id
	public_subnet_id = var.public_subnet_id
	instance_type    = var.instance_type
	admin_cidrs      = var.admin_cidrs
	domain_name      = var.domain_name
	backend_servers  = var.backend_servers
}
```

## Variables

| Name             | Description                                      | Type         | Default         |
|------------------|--------------------------------------------------|--------------|-----------------|
| project_name     | Name of the project                              | string       | n/a             |
| environment      | Environment name (e.g., dev, qa, prod)           | string       | n/a             |
| vpc_id           | VPC ID for deployment                            | string       | n/a             |
| public_subnet_id | Public subnet ID for the Edge VM                 | string       | n/a             |
| instance_type    | EC2 instance type                                | string       | "t3.micro"      |
| admin_user       | Admin username on the instance                   | string       | "ubuntu"        |
| admin_cidrs      | List of CIDRs allowed for SSH/WireGuard access   | list(string) | n/a             |
| wireguard_port   | UDP port for WireGuard                           | number       | 51820           |
| domain_name      | Domain for Caddy HTTPS                           | string       | n/a             |
| backend_servers  | List of backend IP:port addresses                | list(string) | n/a             |

## Outputs

| Name                  | Description                                      |
|-----------------------|--------------------------------------------------|
| edge_instance_id      | The ID of the created Edge VM instance           |
| edge_public_ip        | The public IP address of the Edge VM             |
| edge_private_key_path | Path to the generated private SSH key (local)    |

## Service Configuration

The Edge VM is configured at boot using cloud-init to:
- Enable NAT with iptables and UFW
- Start and enable WireGuard VPN on the specified port
- Start and enable Caddy as a reverse proxy for backend servers with HTTPS
- Restrict access to SSH and WireGuard to the specified admin CIDRs

## Example Directory

The `examples/basic_usage/` folder contains a minimal working example of the edge module. It demonstrates:
- How to configure all required variables
- How to use the generated SSH key for access
- How to validate the deployment manually or with automated tests

### Manual Testing with Examples

```bash
cd examples/basic_usage/
terraform init
terraform apply
# After apply, SSH using the output private key path and public IP:
ssh -i $(terraform output -raw edge_private_key_path) ubuntu@$(terraform output -raw edge_public_ip)
# Validate services:
sudo iptables -t nat -S         # Should show MASQUERADE rule
sudo systemctl is-active wg-quick@wg0  # Should be active
sudo systemctl is-active caddy        # Should be active
```

## Automated Testing with Terratest

Terratest is used to validate the module by building resources, checking outputs, and destroying them after the test.

### Prerequisites
- Go installed (v1.20+ recommended)
- go mod initialized in test/ folder

### Running the Terratest

```bash
cd test/
go mod init edge_module_test
go mod tidy
go test -v edge_module_test.go
```

### Terratest Logic
- Applies the example configuration in `examples/basic_usage/`
- SSHes into the Edge VM using the generated key
- Checks that NAT, WireGuard, and Caddy are all active and correctly configured
- Destroys all resources after the test

**Sample Terratest Output:**
```
=== RUN   TestEdgeModuleIntegration
		edge_module_test.go:20: Applying Edge test resources...
		edge_module_test.go:24: Edge test resources applied.
		edge_module_test.go:28: Destroying Edge test resources...
		edge_module_test.go:30: Edge test resources destroyed.
--- PASS: TestEdgeModuleIntegration (N.NNs)
				--- PASS: TestEdgeModuleIntegration/NAT_MASQUERADE_rule_exists (N.NNs)
				--- PASS: TestEdgeModuleIntegration/WireGuard_service_active (N.NNs)
				--- PASS: TestEdgeModuleIntegration/Caddy_service_active (N.NNs)
PASS
ok      edge_module_test   N.NNs
```

## Notes
- No manual SSH key management is required; the module handles key generation and cleanup.
- All services are installed and configured at boot using cloud-init.
- The example is suitable for both test and production environments with appropriate variable values.
