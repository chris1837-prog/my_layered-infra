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
- **TLS Modes for Primary Domain:**
  - **HTTP Bootstrap:** (`enable_domain_tls = false`) Serve only HTTP (port 80). Use to validate reachability before enabling HTTPS.
  - **Internal CA:** (`enable_domain_tls = true`, `enable_domain_acme = false`) Caddy issues a certificate from its built-in local CA (`tls internal`). Suitable for internal/testing usage.
  - **Public ACME:** (`enable_domain_tls = true`, `enable_domain_acme = true`) Caddy obtains a publicly trusted certificate automatically (Let’s Encrypt/ZeroSSL). Requires public DNS A/AAAA records and open ports 80/443.
- **Split-Horizon Docker Registry Proxy:** The Edge VM also proxies a private Docker registry on two hostnames (external and internal). The Caddy local CA is exposed at `/ca.crt` on both registry hosts for clients to trust, and the CA is installed into the host Docker trust store so the local Docker client can authenticate to the registry via HTTPS.

## Features
- Provisions an Ubuntu EC2 instance as an Edge VM
- Installs and configures NAT (iptables), WireGuard VPN, Caddy reverse proxy, and fail2ban via cloud-init
- Dynamically generates an SSH key pair (no manual key management required)
- Optionally associates an Elastic IP for stable public access (when `eip_allocation_id` is provided)
 - Configurable via variables for VPC, subnet, security group, admin CIDRs, backend servers, and domain
- Outputs the public IP and instance ID
 - Conditional WireGuard provisioning (`enable_wireguard`) so you can disable VPN setup in ephemeral or constrained environments
 - Optional public ACME certificate issuance for the external registry host (`enable_acme_external` + optional `acme_email`)
 - Strong input validation: registry URLs must include an `https://` scheme; backend server list must be non-empty; admin CIDRs list must be non-empty
 - Internal Caddy CA automatically trusted by local Docker daemon using host-only directory names (avoids paths that include a URL scheme)

## Usage

```
module "edge" {
  source = "../../"

  project_name              = "layered-infra"
  environment               = "dev"
  vpc_id                    = aws_vpc.main.id
  edge_private_ip           = "10.0.2.100"
  instance_type             = local.instance_type
  sg_edge_id                = aws_security_group.edge.id
  ubuntu_version            = local.ubuntu_version
  key_name                  = aws_key_pair.edge.key_name
  admin_ssh_keys            = [tls_private_key.edge.public_key_openssh]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_instance_profile.name
  public_subnet_id          = aws_subnet.public_subnet.id
  admin_cidrs               = ["0.0.0.0/0"]
  domain_name               = "edge.example.com"
  enable_domain_tls         = true                 # false = HTTP-only bootstrap
  enable_domain_acme        = true                 # true = public ACME (if enable_domain_tls); false = internal CA
  backend_servers           = ["10.0.2.10:3000", "10.0.2.11:3000"]

  # Private Docker Registry (required)
  registry_user             = "registry"
  registry_password         = "registry"           # mark as sensitive in state
  # Registry URLs MUST include the https:// scheme (validated)
  registry_external_url     = "https://registry.edge.example.com"
  registry_internal_url     = "https://registry.internal.edge.example.com"

  # Toggle features
  enable_wireguard          = true                  # set false to skip VPN installation
  enable_acme_external      = false                 # set true to obtain a public ACME cert for external registry host
  acme_email                = "ops@example.com"     # required when enable_acme_external = true

  # Optional: Associate an existing EIP (omit for ephemeral public IP or if handled elsewhere)
  # eip_allocation_id       = "eipalloc-xxxxxxxxxxxxxxxxx"
}
```

## Variables

| Name                      | Description                                               | Type         | Default         |
|---------------------------|-----------------------------------------------------------|--------------|-----------------|
| project_name              | Name of the project                                       | string       | n/a             |
| environment               | Environment name (e.g., dev, qa, prod)                    | string       | n/a             |
| vpc_id                    | VPC ID where the Edge resources are deployed              | string       | n/a             |
| public_subnet_id          | Public subnet ID for the Edge VM                          | string       | n/a             |
| sg_edge_id                | Security group ID for the Edge VM                         | string       | n/a             |
| instance_type             | EC2 instance type                                          | string       | "t3.micro"      |
| admin_user                | Admin username on the instance                             | string       | "ubuntu"        |
| admin_cidrs               | List of CIDRs allowed for SSH/WireGuard access             | list(string) | ["0.0.0.0/0"]   |
| admin_ssh_keys            | List of public SSH keys for admin user                     | list(string) | n/a             |
| key_name                  | Name of existing AWS Key Pair for SSH access               | string       | n/a             |
| ubuntu_version            | Ubuntu version for the Edge VM                             | string       | "22.04"         |
| iam_instance_profile_name | Name of IAM instance profile to attach to the Edge VM      | string       | n/a             |
| wireguard_port            | UDP port for WireGuard                                     | number       | 51820           |
| domain_name               | Domain for Caddy (HTTP/HTTPS depending on flags)           | string       | n/a             |
| enable_domain_tls         | Enable HTTPS for primary domain (false = HTTP only)        | bool         | true            |
| enable_domain_acme        | Use public ACME cert for primary domain (if TLS enabled)   | bool         | true            |
| backend_servers           | List of backend IP:port addresses                          | list(string) | n/a             |
| edge_private_ip           | Private IP address to assign to the Edge instance          | string       | n/a             |
| registry_user             | Username for the Docker registry                           | string       | n/a             |
| registry_password         | Password for the Docker registry (sensitive)               | string       | n/a             |
| registry_external_url     | External registry URL (must start with https://)           | string       | n/a             |
| registry_internal_url     | Internal registry URL (must start with https://)           | string       | n/a             |
| enable_wireguard          | Whether to install & configure WireGuard VPN               | bool         | true            |
| enable_acme_external      | Use public ACME cert for external registry host            | bool         | false           |
| acme_email                | Contact email for ACME when public certs enabled           | string       | ""              |
| eip_allocation_id         | Existing EIP allocation ID to associate (optional)         | string       | null            |
| common_tags               | Map of tags to assign to all resources                     | map(string)  | {}              |

## Outputs

| Name                         | Description                                    |
|------------------------------|------------------------------------------------|
| edge_instance_id             | The ID of the created Edge VM instance         |
| edge_public_ip               | The public IP address of the Edge VM           |
| primary_network_interface_id | The primary network interface ID of the VM     |

## Service Configuration

The Edge VM is configured at boot using a single cloud-init script to:
- Enable NAT with iptables and UFW
- Start and enable WireGuard VPN on the specified port
- Start and enable Caddy as a reverse proxy for backend servers with HTTPS
- Install and enable fail2ban to protect SSH from brute-force attacks
- Restrict access to SSH and WireGuard to the specified admin CIDRs
 - (If `enable_acme_external=false`) install the Caddy internal CA into Docker trust directories named after the registry hostnames (host only, excluding scheme) so local Docker can trust the self-issued certificates. When `enable_acme_external=true`, CA trust dirs for the external registry host are intentionally not populated.

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

#### Test Coverage Summary (short)
The integration test exercises the full lifecycle and key behaviors of the Edge appliance:

* Provisioning & Cloud-Init: waits for custom or native completion markers; emits rich diagnostics if slow or failed.
* DNS Readiness Gate: optional strict/warn/skip pre-check for primary + external registry hosts before ACME attempts.
* Docker Runtime: validates Docker installation availability with retries.
* Registry (Split-Horizon): ensures registry container is running; validates Caddyfile contains both registry domains.
* TLS Mode Detection: infers external registry TLS mode (ACME vs internal CA) and adapts expectations (issuer vs local CA trust files).
* Auth Flows: checks unauthenticated (401), wrong credentials (401), and correct credentials (200) responses for both registry hosts.
* Credential Extraction: parses `startup.sh` to confirm generated htpasswd credentials are in place.
* Push/Pull Cycle: tags, pushes, removes, and pulls an image to verify end-to-end registry path and content addressing.
* Docker Trust Store: asserts internal host always has CA; external host has CA only in internal-CA mode (warns if unexpected).
* NAT: verifies presence of `MASQUERADE` rule.
* Services: asserts WireGuard, Caddy, fail2ban active; fail2ban sshd jail present.
* Optional External Client (env flags): can provision an outside-VPC client to test external registry + optional Docker Hub flow.
* Diagnostic Depth: on failures (cloud-init, Docker, ACME) captures logs (cloud-init, systemd, Caddy journal, registry logs) for rapid triage.


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
