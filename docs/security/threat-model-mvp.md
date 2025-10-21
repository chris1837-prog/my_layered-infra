# MVP Threat Model (STRIDE)

## Overview
- **Objective**: Identify and prioritize security threats against the MVP deployment so the team can target mitigations before scaling usage.
- **Scope**: The single-host Compose stack (Node.js app, PgBouncer, Postgres) running on an EC2 app VM inside a private subnet, its supporting Edge/NAT instance for controlled egress, attached EBS data volume, and backup workflows.
- **Method**: STRIDE categories with qualitative impact and likelihood ratings (High / Medium / Low). Ratings reflect current controls observed in this repo and expected AWS defaults.

## Architecture Baseline
- **Edge VM (NAT)**: Public-subnet instance that brokers outbound internet access for private workloads and is reachable via SSH for operations.
- **App VM (private subnet)**: Hosts the Docker Compose stack. Inside the host, containers communicate on an isolated bridge network (`app → PgBouncer → Postgres`).
- **Postgres data volume**: Dedicated EBS volume bind-mounted into the Postgres container (`/var/lib/postgresql/data`) per ADR-0012.
- **Backups**: `backup-restore.sh` produces dumps that live on the host filesystem before transfer to long-term storage.
- **Administrative access**: Engineers use SSH (likely via SSM Session Manager or bastion) and Docker CLI to operate the stack; Terraform automates infra in AWS accounts.

### Trust Boundaries & Key Assets
- **Internet ↔ Edge VM**: First line exposed to the public internet; compromises here can bridge into the private network.
- **Edge VM ↔ Private Subnet**: Only vetted traffic should traverse from edge to private workloads; lateral movement risk.
- **Host ↔ Containers**: Containers run with elevated access to host file paths; breakout can modify host or other containers.
- **PgBouncer ↔ Postgres**: Controls database authentication/authorization; credentials and TLS material are sensitive.
- **Backups at rest/in transit**: Contain full customer data snapshots; mishandling leaks confidential information.

## STRIDE Threat Inventory

| ID | STRIDE | Threat | Impact | Likelihood | Recommended Mitigations |
|----|--------|--------|--------|------------|-------------------------|
| T1 | Elevation of Privilege | **Edge VM compromise enables pivot into private subnet.** Adversary leverages SSH exposure or unpatched services on the Edge/NAT host to route into the app subnet and target the Compose stack. | High | Medium | Harden edge host (minimal packages, auto-updates), enforce host-based firewall restricting SSH sources, require MFA-backed bastion/SSM, monitor for anomalous east-west traffic, and automate rebuilds from golden images. |
| T2 | Spoofing | **PgBouncer credentials or certificates are stolen and replayed from untrusted hosts.** Attackers reuse leaked secrets to reach Postgres through PgBouncer or direct DB endpoints, bypassing app-level controls. | High | Medium | Shift to mTLS per `SECURITY_NOTES`, rotate secrets via AWS Secrets Manager/Parameter Store, scope security groups to trusted CIDRs, and enable failed-auth alerting. |
| T3 | Tampering | **Container breakout from the app service modifies PgBouncer/Postgres config or data.** Exploiting vulnerable packages or Docker socket access lets an attacker alter configurations or binaries on the host volume. | High | Low | Run containers as non-root with dropped Linux capabilities, apply AppArmor/SELinux profiles, keep base images patched, mount volumes as read-only where possible, and isolate Docker control plane (no socket binding into containers). |
| T4 | Repudiation | **Insufficient audit trails for privileged actions.** SSH sessions, Docker operations, and PgBouncer admin commands lack centralized logging, preventing incident reconstruction or non-repudiation. | Medium | Medium | Centralize logs via CloudWatch/CloudTrail + SSM Session Manager recording, enable PgBouncer auth logging and Postgres `pgaudit`, and require operational runbooks to capture change tickets. |
| T5 | Information Disclosure | **Unencrypted database backups or snapshots are exfiltrated.** Dumps stored on the host or copied over the Edge link can be harvested from filesystem access or intercepted in transit. | High | Medium | Encrypt backups at rest (KMS-managed S3 buckets or LUKS on host), restrict backup directories to least-privileged users, use TLS when transferring off-host, and scrub aged snapshots automatically. |
| T6 | Denial of Service | **Connection pool exhaustion at PgBouncer knocks the app offline.** Malicious actors or runaway processes open excessive client sessions, consuming `MAX_CLIENT_CONN` and blocking legitimate traffic. | Medium | Medium | Configure per-client limits, implement application-level rate limiting, monitor pool metrics with alerting, and apply circuit breakers/graceful degradation in the app. |

## Prioritized Follow-Ups
- Implement mTLS and secret rotation for PgBouncer/Postgres before external beta access.
- Bake hardened AMIs for Edge/App hosts with baseline CIS controls and automated patching.
- Stand up centralized logging (CloudWatch Logs + GuardDuty/IAM Access Analyzer) to close repudiation gaps.
- Define a backup retention & encryption policy, including verification of restore procedures under least privilege.
