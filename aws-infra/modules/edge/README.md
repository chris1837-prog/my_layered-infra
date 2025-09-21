# Edge Module for NAT, WireGuard, and Caddy

This module provisions a secure Edge VM on AWS, providing NAT, WireGuard VPN, Caddy reverse proxy, and SSH brute-force protection with fail2ban. It is designed for platform and network engineers to enable secure ingress/egress and VPN access, with all key management and service configuration handled automatically via a unified cloud-init script.

## Architecture and Rationale

This module provisions a hardened **Edge VM** for your AWS environment. The Edge VM acts as a secure, multi-purpose entry point, handling security, traffic management, and administrator access. The entire server is configured automatically on its first boot using a single, unified `cloud-init` script, ensuring every deployment is reliable, repeatable, and secure by default.

## Core Features and Logic

The Edge VM is responsible for three primary functions: providing secure network routing, enabling encrypted administrator access, and managing public web traffic.

### 1. Secure Network Foundation (NAT & Firewall)

**Why this is important:** The Edge VM acts as a gatekeeper. It lives in a public subnet and is designed to protect the application servers, which will live in a private subnet with no direct internet access.

- **NAT Gateway:** The instance is configured to act as a Network Address Translation (NAT) gateway. This allows instances in the private subnet to initiate outbound connections to the internet (for example, to download software updates or connect to third-party APIs) without having a public IP address themselves. This is achieved by enabling IP forwarding and using a dynamic `iptables MASQUERADE` rule.
- **UFW Firewall:** The Uncomplicated Firewall (UFW) is enabled by default to deny all incoming traffic. The `cloud-init` script then creates explicit rules to only allow traffic for essential services:
  - **SSH (port 22/tcp):** Limited to a specific list of administrator IP addresses.
  - **WireGuard (port 51820/udp):** Limited to the same administrator IP addresses.
  - **HTTP/HTTPS (ports 80/443):** Open to the public internet for web traffic.

### 2. Administrator Access (WireGuard VPN)

**Why this is important:** To manage resources in the private subnet, administrators need a secure way to "enter" the cloud network. A VPN is the standard, secure solution.

- **WireGuard Server:** A WireGuard VPN server is automatically installed and configured on boot. It creates a secure, encrypted tunnel for administrators to connect to the VPC. The server's keys are generated on the instance itself, and the service is enabled to start automatically.

### 3. Web Traffic Management (Caddy Reverse Proxy)

**Why this is important:** Caddy provides a modern, secure way to handle all incoming web traffic. It terminates HTTPS, manages TLS certificates, and forwards requests to the correct backend application.

- **Reverse Proxy:** Caddy is configured to listen for traffic on its public interface and forward it to the application servers running in the private subnet.
- **Automatic HTTPS (Internal TLS):** For this initial setup, Caddy is configured to use `tls internal`. It creates its own private Certificate Authority (CA) and issues a trusted certificate for internal use. This allows us to test the entire HTTPS and proxying workflow without needing public DNS configured yet.

## Features
- Provisions an Ubuntu EC2 instance as an Edge VM
- Installs and configures NAT (iptables), WireGuard VPN, Caddy reverse proxy, and fail2ban via cloud-init
- Dynamically generates an SSH key pair (no manual key management required)
- Assigns an Elastic IP for stable public access
- Configurable via variables for VPC, subnet, admin CIDRs, backend servers, and domain
- Outputs the public IP and instance ID

## Usage

```
module "edge" {
  source = "../../"

  project_name              = "layered-infra"
  environment               = "dev"
  vpc_id                    = aws_vpc.test_vpc.id
  instance_type             = local.instance_type
  sg_edge_id                = aws_security_group.edge.id
  ubuntu_version            = local.ubuntu_version
  key_name                  = aws_key_pair.edge.key_name
  admin_ssh_keys            = [tls_private_key.edge.public_key_openssh]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_instance_profile.name
  public_subnet_id          = aws_subnet.public_subnet.id
  admin_cidrs               = ["0.0.0.0/0"]
  domain_name               = "edge.example.com"
  backend_servers           = ["10.0.2.10:3000", "10.0.2.11:3000"]
}
```

## Variables

| Name                      | Description                                               | Type         | Default         |
|---------------------------|-----------------------------------------------------------|--------------|-----------------|
| project_name              | Name of the project                                       | string       | n/a             |
| environment               | Environment name (e.g., dev, qa, prod)                    | string       | n/a             |
| vpc_id                    | VPC ID for deployment                                    	| string       | n/a             |
| public_subnet_id          | Public subnet ID for the Edge VM                         	| string       | n/a             |
| sg_edge_id                | Security group ID for the Edge VM                        	| string       | n/a             |
| instance_type             | EC2 instance type                                        	| string       | "t3.micro"      |
| admin_user                | Admin username on the instance                           	| string       | "ubuntu"        |
| admin_cidrs               | List of CIDRs allowed for SSH/WireGuard access           	| list(string) | ["0.0.0.0/0"]   |
| admin_ssh_keys            | List of public SSH keys for admin user                   	| list(string) | n/a             |
| key_name                  | Name of existing AWS Key Pair for SSH access             	| string       | n/a             |
| ubuntu_version            | Ubuntu version for the Edge VM                          	| string       | "22.04"         |
| iam_instance_profile_name | Name of IAM instance profile to attach to the Edge VM    	| string       | n/a             |
| wireguard_port            | UDP port for WireGuard                                   	| number       | 51820           |
| domain_name               | Domain for Caddy HTTPS                                  	| string       | n/a             |
| backend_servers           | List of backend IP:port addresses                       	| list(string) | n/a             |
| common_tags               | Map of tags to assign to all resources                  	| map(string)  | {}              |

## Outputs

| Name             | Description                            |
|------------------|----------------------------------------|
| edge_instance_id | The ID of the created Edge VM instance |
| edge_public_ip   | The public IP address of the Edge VM   |

## Service Configuration

The Edge VM is configured at boot using a single cloud-init script to:
- Enable NAT with iptables and UFW
- Start and enable WireGuard VPN on the specified port
- Start and enable Caddy as a reverse proxy for backend servers with HTTPS
- Install and enable fail2ban to protect SSH from brute-force attacks
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
sudo iptables -t nat -S                # Should show MASQUERADE rule
sudo systemctl is-active wg-quick@wg0  # Should be active
sudo systemctl is-active caddy         # Should be active
sudo systemctl is-active fail2ban      # Should be active
sudo fail2ban-client status sshd       # Should show jail is running
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
- Checks that NAT, WireGuard, Caddy, and fail2ban are all active and correctly configured
- Verifies fail2ban sshd jail is present
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
		--- PASS: TestEdgeModuleIntegration/fail2ban_service_active (N.NNs)
		--- PASS: TestEdgeModuleIntegration/fail2ban_sshd_jail_present (N.NNs)
PASS
ok      edge_module_test   N.NNs
```

## Notes
- No manual SSH key management is required; the module handles key generation and cleanup.
- All services (NAT, UFW, WireGuard, Caddy, fail2ban) are installed and configured at boot using cloud-init.
- The example is suitable for both test and production environments with appropriate variable values.
