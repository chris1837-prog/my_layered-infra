## Postgres EBS Snapshot Runbook (Area 2 – Task C5)
This procedure uses the AWS CLI to create, tag, and manage manual snapshots of a Postgres data volume. It stays within the scope of the EBS module and avoids altering global infrastructure (e.g., environments or bootstrap). Additionally, it covers naming/tagging policy, retention guidance, and IAM least privilege.

### Prerequisites
Postgres data lives on a dedicated EBS volume mounted at `/var/lib/postgresql/data` (Area 1).  
AWS CLI configured with an IAM principal allowed to create/describe/tag/delete snapshots (see IAM below).  
Know the environment (`dev|staging|prod`) and project tag values (e.g., `GP1`).

### Naming & Tagging Policy
Snapshot name format:  
`<Project>-<Env>-pgdata-<YYYYMMDD-HHMM>-<Ticket>`

**Example:**  
`GP1-dev-pgdata-20251001-1045-C5`

**Required tags:**
Project = GP1  
Env = dev|staging|prod  
Role = postgres-data  
BackupType = manual  
Owner = Squad-C  
Ticket = C5 (e.g., C5-123)

### Procedure (AWS CLI)
**1. Identify volume**
```bash
VOL_ID=$(aws ec2 describe-volumes \
  --filters "Name=tag:Role,Values=postgres-data" "Name=tag:Env,Values=dev" \
  --query "Volumes[0].VolumeId" --output text)
echo "VOL_ID=$VOL_ID"
```

**2. Create Snapshot**
```bash
SNAP_DESC="GP1 dev Postgres data snapshot before deploy"
SNAP_NAME="GP1-dev-pgdata-$(date +%Y%m%d-%H%M)-C5"
SNAP_ID=$(aws ec2 create-snapshot \
  --volume-id "$VOL_ID" \
  --description "$SNAP_DESC" \
  --query "SnapshotId" --output text)
echo "SNAP_ID=$SNAP_ID"
```

**3. Tag Snapshot**
```bash
aws ec2 create-tags --resources "$SNAP_ID" --tags \
  Key=Name,Value="$SNAP_NAME" \
  Key=Project,Value=GP1 \
  Key=Env,Value=dev \
  Key=Role,Value=postgres-data \
  Key=BackupType,Value=manual \
  Key=Owner,Value=Squad-C
```

**4. Wait until completed & validated**
```bash
aws ec2 wait snapshot-completed --snapshot-ids "$SNAP_ID"
aws ec2 describe-snapshots --snapshot-ids "$SNAP_ID" \
  --query "Snapshots[0].State"
echo "Snapshot $SNAP_ID ($SNAP_NAME) ready."
```  


### Retention Guidance
Dev: keep last 3 manual snapshots  
Staging: keep last 7  
Prod: keep last 30 (or 14 if space/cost constrained)  
Monthly long-term: keep 12  
Retention policy should be enforced via lifecycle or scheduled cleanup scripts if automated later.  


### IAM Least-Privilege Example
**Allow:**
ec2:CreateSnapshot  
ec2:DeleteSnapshot  
ec2:Describe*  
ec2:CreateTags  
ec2:ModifySnapshotAttribute

**Conditions:**  
Restrict by resource (snapshot/volume ARNs) and tag constraints, e.g.  
`"aws:RequestTag/Project": "GP1"`  

### Notes
For write-consistent snapshots of running Postgres: prefer pg_start_backup/pg_stop_backup, pg_basebackup, or filesystem freeze.  
For now: keep it manual and document consistency caveats.  
Performance: gp3 throughput/IOPS can be tuned; document defaults.  
Encrypted volumes: specify kms_key_id explicitly in regulated environments.  
This manual procedure can later be integrated into an automated runbook or CI/CD pipeline once validated.
