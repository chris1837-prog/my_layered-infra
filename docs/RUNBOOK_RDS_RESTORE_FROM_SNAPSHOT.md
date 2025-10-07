# Runbook: RDS PostgreSQL – Restore-from-Snapshot (Dry Run)

## Purpose
Prove that our backups are restorable without touching the live database.  
This dry run restores an **RDS snapshot** into a **temporary RDS instance**, verifies data, then cleans up.

## Scope
- DB engine: **Amazon RDS for PostgreSQL** (dev environment)
- This is a **manual** procedure (automation later).
- We do **not** restore over the live DB.

## Prerequisites
- AWS Console access. **Administrator** permissions required to create/restore snapshots.
- If you only have **ReadOnly**, hand this runbook to someone with Admin and record results.

## Inputs
- Source DB identifier: `layered-dev-rds`
- Region: `eu-central-1`
- Snapshot naming (proposal): `layered-<env>-rds-snap-YYYYMMDD-HHMM`  
  (example: `layered-dev-rds-snap-20251007-1100`)

## High-level Dry Run (what we’ll do)
1. Pick a snapshot of `layered-dev-rds` (or create a manual one).
2. **Restore** snapshot to a **new temporary RDS instance** (e.g. `layered-dev-rds-restore-test`).
3. **Verify**: connect to the temporary instance and check expected data (e.g., sentinel row).
4. **Clean up**: delete the temporary instance (and auto-snapshot if created).

---
## Detailed Steps

### 1. Select a Snapshot
1. In the AWS Console, go to **RDS → Snapshots**.  
2. Find a snapshot of the target database (example: `layered-dev-rds-snap-20251007-1100`).  
3. Make sure the snapshot status is **available**.

### 2. Restore to a Temporary Instance
1. Select the snapshot → **Actions → Restore snapshot**.  
2. Set the new DB identifier to something clear, e.g.  
   `layered-dev-rds-restore-test`.  
3. Keep the same engine and version as the original DB.  
4. Use the same VPC and subnet group (`layered-dev-vpc`).  
5. Optional: set instance class to a smaller type (`db.t3.micro`) for cost saving.  
6. Leave *Public access* disabled.  
7. Start the restore and wait until the status is **Available**.

### 3. Verify the Restore
1. Copy the endpoint of the restored DB.  
2. Connect with a SQL client or `psql`, for example:
   ```bash
   psql -h layered-dev-rds-restore-test.xxxxx.eu-central-1.rds.amazonaws.com -U <username> -d <dbname>
3. Run a quick check, e.g.:
   ```sql
   SELECT * FROM restore_sentinel;
   ```
   If the sentinel row appears → ✅ backup verified.

### 4. Clean Up
1. Stop any connections.  
2. In AWS Console → RDS → select the restored instance → Actions → Delete.
3. Disable “Create final snapshot” to avoid extra storage cost.
4. Confirm deletion.

### Notes
- Always perform this test in development or staging, never on production.
- Record the result (date, snapshot name, verification outcome) in your team documentation or Confluence.




