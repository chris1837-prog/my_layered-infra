# ADR 0003 – Why WireGuard for VPN Access

**Status:** Accepted

## Context
The team required a **secure, high-performance VPN** for developers and CI systems accessing private infrastructure.  
Traditional solutions like OpenVPN or IPSec are mature but heavy, slow, and complex to configure.  
A smaller team benefits more from a simpler, auditable, modern protocol with minimal overhead and strong cryptographic defaults.

## Decision
We selected **WireGuard** as our VPN solution.  
WireGuard features a small, auditable codebase (~4 K lines vs OpenVPN’s >100 K), reducing the attack surface.  
It runs in kernel space using efficient cryptography (ChaCha20, Poly1305), offering **2–4× higher throughput** than OpenVPN or IPSec.  
It’s cross-platform (Linux, macOS, Windows, iOS, Android) and easy to automate with Ansible or Terraform.  
Engineers can connect quickly with minimal setup, and the project incurs no licensing costs.

## Consequences
WireGuard improves **security, simplicity, and performance** while lowering maintenance effort.  
- **Positive:** Modern cryptography, fast performance, easy automation, no licensing costs.  
- **Negative:** Lacks built-in user management and advanced access-control features.  
- **Trade-off:** Requires pairing with an external identity/provisioning layer for MFA, but the benefits in speed and simplicity outweigh this for an engineering-focused team.

