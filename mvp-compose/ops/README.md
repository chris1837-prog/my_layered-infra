# Ops Helpers

- `mount-postgres-ebs.sh` — one-time helper to format and mount the dedicated EBS volume on the host. Usage:

  ```bash
  sudo DEVICE=/dev/xvdb MOUNTPOINT=/var/lib/postgresql/data ./mount-postgres-ebs.sh
  ```

  Adjust `DEVICE` if your volume is exposed under a different name (NVMe instances, e.g. `/dev/nvme1n1`). The script:
  - Verifies dependencies (`lsblk`, `blkid`).
  - Formats the disk as ext4 if needed.
  - Adds a persistent entry to `/etc/fstab`.
  - Mounts it and sets ownership to Postgres’ default UID/GID (`999`).

After mounting, bring `docker compose` up and run the sentinel test (see repo README) to confirm persistence across restarts.

> Local tip: when running on laptops, set `POSTGRES_DATA_SOURCE=/tmp/pgdata` (or similar writable path) before `docker compose up` so the bind mount does not require sudo.
