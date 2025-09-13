# AWS Edge VM Module

This Terraform module provisions a hardened **Edge VM** for the project. This instance serves as a secure, multi-purpose entry point to the cloud environment, handling security, traffic management, and administrator access.

The entire server is configured automatically on its first boot using a single, unified `cloud-init` script. This ensures that every deployment is reliable, repeatable, and secure by default.

---
## Core Features and Logic

The Edge VM is responsible for three primary functions: providing secure network routing, enabling encrypted administrator access, and managing public web traffic.

### 1. Secure Network Foundation (NAT & Firewall)

**Why this is important:** The Edge VM acts as a gatekeeper. It lives in a public subnet and is designed to protect the application servers, which will live in a private subnet with no direct internet access.

*	**NAT Gateway:** The instance is configured to act as a Network Address Translation (NAT) gateway. This allows instances in the private subnet to initiate outbound connections to the internet (for example, to download software updates or connect to third-party APIs) without having a public IP address themselves. This is achieved by enabling IP forwarding and using a dynamic `iptables MASQUERADE` rule.
*	**UFW Firewall:** The Uncomplicated Firewall (UFW) is enabled by default to deny all incoming traffic. The `cloud-init` script then creates explicit rules to only allow traffic for essential services:
	*	**SSH (port 22/tcp):** Limited to a specific list of administrator IP addresses.
	*	**WireGuard (port 51820/udp):** Limited to the same administrator IP addresses.
	*	**HTTP/HTTPS (ports 80/443):** Open to the public internet for web traffic.

### 2. Administrator Access (WireGuard VPN)

**Why this is important:** To manage resources in the private subnet, administrators need a secure way to "enter" the cloud network. A VPN is the standard, secure solution.

*	**WireGuard Server:** A WireGuard VPN server is automatically installed and configured on boot. It creates a secure, encrypted tunnel for administrators to connect to the VPC. The server's keys are generated on the instance itself, and the service is enabled to start automatically.

### 3. Web Traffic Management (Caddy Reverse Proxy)

**Why this is important:** Caddy provides a modern, secure way to handle all incoming web traffic. It terminates HTTPS, manages TLS certificates, and forwards requests to the correct backend application.

*	**Reverse Proxy:** Caddy is configured to listen for traffic on its public interface and forward it to the application servers running in the private subnet.
*	**Automatic HTTPS (Internal TLS):** For this initial setup, Caddy is configured to use `tls internal`. It creates its own private Certificate Authority (CA) and issues a trusted certificate for internal use. This allows us to test the entire HTTPS and proxying workflow without needing public DNS configured yet.

---
## How to Test and Verify

After running `terraform apply`, you can use the following commands to verify that each component was configured correctly.

### 1. Test SSH Access and NAT

First, connect to the server using its public IP. This validates that the user was created correctly and the firewall rules for SSH are working.

	ssh -i /path/to/your/private_key ubuntu@<YOUR_EDGE_PUBLIC_IP>

Once connected, test the NAT functionality by pinging a public server.

	# Run this on the Edge VM
	ping -c 3 google.com

**Success looks like:**
	PING google.com (142.250.184.206) 56(84) bytes of data.
	64 bytes from fra24s11-in-f14.1e100.net (142.250.184.206): icmp_seq=1 ttl=117 time=0.820 ms
	...

### 2. Test WireGuard Server

Check that the WireGuard service is active and listening for connections.

	# Run this on the Edge VM
	sudo wg

**Success looks like:**
	interface: wg0
	  public key: 6pIRcJMZnyDM1z0L3PMpcx8giny1PAnF2J33TclZ+FU=
	  private key: (hidden)
	  listening port: 51820

### 3. Test Caddy Reverse Proxy

Run this command from your **local machine**. It uses the `--resolve` flag to test the HTTPS connection without needing a real DNS record.

	# On your local machine
	curl -k -v https://staging.example.com --resolve staging.example.com:443:<YOUR_EDGE_PUBLIC_IP>

**Success looks like:** A successful TLS handshake followed by a `502 Bad Gateway` error. The 502 error is expected and correct because the backend application server does not exist yet. The key is to see the successful TLS connection.

	* Trying 63.178.33.66:443...
	* Connected to staging.example.com (63.178.33.66) port 443 (#0)
	...
	* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
	* Server certificate:
	* subject: [NONE]
	* issuer: CN=Caddy Local Authority - ECC Intermediate
	...
	> GET / HTTP/2
	...
	< HTTP/2 502
	...