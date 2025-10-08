# Runbook:  PostgreSQL – Restore-from-Snapshot (Dry Run)

## Scope and Assumptions

This runbook explains how to restore the PostgreSQL database that runs inside a Docker container on an EC2 instance.  
The database data is stored on an EBS volume that is attached to the EC2 instance.

We are **not using RDS** in this setup.  
Any RDS resources (for example `layered-dev-rds`) are not part of this runbook.

This runbook is used when:
- The database volume is lost, corrupted, or  
- You need to roll back to an earlier snapshot.

## Step 2 – Prerequisites and Safety Checks

Before starting the restore, make sure everything below is ready.

### Prerequisites
- You have access to the **AWS Console** or **AWS CLI**.  
- You know the **EC2 instance ID** where the database runs.  
- You know the **snapshot ID** you want to restore from.  
- The EC2 instance is **stopped** or the database container is **not running** during restore (to avoid data corruption).  
- You have permission for:
  - `ec2:CreateVolume`
  - `ec2:AttachVolume`
  - `ec2:DescribeSnapshots`

### Safety Checks
1. Confirm the snapshot you will use has **the correct date** and **status = completed**.  
2. Confirm that **no other volume** with the same data path is still attached to the EC2 instance.  
3. Double-check that the snapshot belongs to the **same region** as the EC2 instance.  
4. Make sure you have a **recent backup** before doing the restore.

## Step 3 – Create a New Volume from the Snapshot

This step creates a new EBS volume that contains all data from the snapshot.

### Steps
1. Go to the **AWS Console → EC2 → Snapshots**.  
2. Find the snapshot you want to restore from.  
3. Click **“Create volume from snapshot.”**  
4. In the dialog:
   - Choose the **same Availability Zone (AZ)** as your EC2 instance.  
   - Keep the same **volume type** and **size** as the original volume.  
   - Add a clear name tag, for example:  
     ```
     Name = restored-db-volume-2025-10-08
     ```
5. Click **Create Volume**.  
6. Wait until the new volume status is **“available.”**

🟢 Once it is available, it’s ready to attach to the EC2 instance.

## Step 4 – Attach the New Volume to the EC2 Instance

Now we will attach the new EBS volume to the EC2 instance that runs the database container.

### Steps
1. Go to the **AWS Console → EC2 → Volumes**.  
2. Find the new volume you created in Step 3.  
3. Select the volume and click **“Attach volume.”**  
4. Choose the correct **EC2 instance** (the one that runs PostgreSQL).  
5. For the device name, you can keep the default (for example `/dev/sdf`).  
6. Click **Attach Volume.**

After attaching:
- The new volume is now connected to your EC2 instance,  
  but it is **not yet mounted** inside the system.

Next, we will mount the volume and make sure PostgreSQL can read it.

## Step 5 – Mount the Volume on the EC2 Instance

Now we make the new EBS volume visible inside the EC2 instance so that PostgreSQL can use it.

### Steps
1. Connect to the EC2 instance (for example, using SSH or VPN).  
2. List all available disks:
   ```bash
   lsblk
   ```
You should see the new volume (for example /dev/xvdf).

3. Create a mount point (only if it doesn’t already exist):
   ```
   sudo mkdir -p /data/postgres
   ```
Mount the volume:
   ```
   sudo mount /dev/xvdf /data/postgres
   ```
Check that the volume is mounted correctly:
   ```
   df -h
   ```
You should see /data/postgres in the list.

⚠️ Note: The path /data/postgres is an example.
Use the same path that your Docker container uses for database storage (e.g., /var/lib/postgresql/data).

When the volume is mounted, it’s ready for PostgreSQL to read the data again.

## Step 6 – Start the PostgreSQL Container

Now that the restored EBS volume is mounted, you can start the PostgreSQL container again.

### Steps
1. On the EC2 instance, list all Docker containers:
   ```bash
   docker ps -a
   ```
   Find the container that runs PostgreSQL (for example, `layered-postgres`).

2. Start the container:
   ```bash
   docker start layered-postgres
   ```

3. Check the logs to confirm that PostgreSQL starts without errors:
   ```bash
   docker logs -f layered-postgres
   ```

4. When the container is running, connect to the database:
   ```bash
   docker exec -it layered-postgres psql -U <db_user> -d <db_name>
   ```

5. Run a simple query to confirm data is restored:
   ```sql
   SELECT COUNT(*) FROM information_schema.tables;
   ```

If you see tables and no errors, the restore worked successfully.

## Step 7 – Verification and Cleanup

After the PostgreSQL container is running and data is confirmed, do a few final checks and cleanups.

### Verification
1. Make sure your application can connect to the database again.  
   - If the app uses PgBouncer, confirm it connects without errors.  
   - Test a simple API call or query from the app.
2. Check database health inside PostgreSQL:
   ```sql
   SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database;
   ```
   This shows that databases are readable and have data sizes.
3. Optionally, check that extensions (like PostGIS) are available:
   ```sql
   \dx
   ```

### Cleanup
1. Delete the old or corrupted volume if it’s no longer needed.  
2. Create a **new snapshot** of the restored volume for backup:
   - Go to **EC2 → Volumes → Create Snapshot**.  
   - Name it clearly, for example:  
     ```
     Name = post-restore-backup-2025-10-08
     ```
3. Update documentation or monitoring if volume IDs changed.  
4. Inform your team that the restore is complete and verified.

✅ The database restore process is now finished.

## Step 8 – Summary and Notes

### Summary
- This runbook explains how to restore a PostgreSQL database running in a Docker container on an EC2 instance.  
- The database data is stored on an EBS volume, and the restore process uses an existing snapshot.  
- The main actions are:
  1. Create a new volume from a snapshot.  
  2. Attach and mount the volume to the EC2 instance.  
  3. Start the PostgreSQL container.  
  4. Verify data and create a new snapshot backup.

### Notes
- Always stop the database or container before doing a restore to avoid data corruption.  
- Make sure the new volume is created in the **same Availability Zone** as the EC2 instance.  
- If you use **PgBouncer**, restart it after PostgreSQL is restored to refresh connections.  
- Keep a record of the new volume ID and snapshot ID for auditing.  
- Consider automating snapshots for regular backups.

✅ **End of Runbook**




