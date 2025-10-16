---

## 🧠 Architectural Decision (ADR-0012-postgres-on-ebs)

### Context

Our EC2-hosted Postgres currently relies on the root volume. The C5 initiative requires durable storage with predictable backup/restore workflows. We also need a clean interface between infrastructure (EBS provisioning), host bootstrap (format/mount), and the Compose stack (bind-mounting the data directory).

Key drivers:
- Snapshots should only target the Postgres data volume.
- Hosts in single-instance and Auto Scaling patterns must share the same expectations.
- Operations needs a documented mount/runbook process.

### Decision

1. Introduced a dedicated Terraform module (`aws-infra/modules/ebs_data_volume`) that provisions a tagged EBS volume and optionally attaches it to a single instance.
2. Added an isolated example under `aws-infra/environments/examples/c5-area1` so testing happens in the `layered_qa` account without touching shared stacks.
3. Ship a one-time host script (`mvp-compose/ops/mount-postgres-ebs.sh`) that formats, mounts, persists in `/etc/fstab`, and corrects ownership for UID 999.
4. Updated `mvp-compose/docker-compose.yml` to bind-mount `/var/lib/postgresql/data` directly from the host path and made the `PGDATA` setting explicit.

### Consequences

- ✅ Snapshots now operate on a clearly tagged, standalone volume (`Role=postgres-data`).
- ✅ Compose restarts reuse the mounted volume; sentinel tests survive container restarts.
- ✅ Future automation (Area 2 & 3) can rely on predictable mount paths and tagging.
- ⚠️ For local non-EC2 development, engineers must point `POSTGRES_DATA_SOURCE` to a writable host path (the default `/var/lib/postgresql/data` requires sudo on Linux/macOS).
- ⚠️ Multi-instance setups still require launch-template wiring (documented in the module notes but not automated here).
