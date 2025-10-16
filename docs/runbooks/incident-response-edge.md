# Incident Response Runbook — Edge VM

**Purpose:** Step-by-step actions for a suspected security incident on the Edge VM.

**When to use:** Any alerts, suspicious traffic, or compromise indicators on the Edge VM.

---

## The 5 C’s of Incident Response

### 1. Containment
- Isolate the Edge VM using a dedicated **Quarantine Security Group** in AWS (no ingress/egress).
- Stop public access via AWS Console → EC2 → Networking → Change Security Groups → select *quarantine-no-egress*.
- Do **not** reboot or terminate until evidence is captured.
> **Note:** The `quarantine-no-egress` Security Group does not currently exist.  
> Coordinate with the networking team to create this group as part of a future task.

## 2. Collection
- From your terminal, use the AWS CLI to create snapshots for all attached EBS volumes.

```bash
# Identify volumes attached to the compromised instance
aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=<INSTANCE_ID> --query "Volumes[*].VolumeId" --output text

# Create snapshots for each attached volume
aws ec2 create-snapshot --volume-id <VOLUME_ID> --description "Forensic snapshot from Edge VM incident"
```

> **Note:**  
> Replace `<INSTANCE_ID>` and `<VOLUME_ID>` with the actual IDs from your AWS environment.  
> You can find these by running `aws ec2 describe-instances` (for instance IDs) and `aws ec2 describe-volumes` (for volume IDs), or by checking the **EC2 → Instances → Storage** tab in the AWS Console.  
> Tag each snapshot with the relevant `IncidentID`, `Timestamp`, and `Owner`, and retain them per your organization’s evidence policy.

## 3. Correction
- After evidence is preserved, **terminate** the compromised instance.

- **Re-deploy a clean instance via GitHub Actions CI/CD**  
  1) In GitHub → **Actions** tab → select the infra deploy workflow (e.g., **“Deploy Edge Infra”**).  
  2) Click **Run workflow** → choose the correct **branch** (usually `development`) and **environment** (e.g., `dev`/`staging`/`prod`).  
  3) Click **Run workflow** and wait for the job to complete.  
  4) Verify in AWS **EC2 → Instances** that the new Edge VM is **running** and healthy.

- **Post-deploy steps**  
  - Attach standard **Security Groups** (remove quarantine).  
  - **Rotate** any secrets/keys used by the compromised VM.  
  - Validate app health checks and logging/metrics.  
  - Record the new **Instance ID** and AMI in the incident notes.

> **Note:** This project uses **GitHub Actions** (not Terraform Cloud) to build an


### 4. Communication
- Notify on-call and leadership via Slack channel `#incidents`.
- Update the incident ticket every 60 minutes until resolved.
- Use the stakeholder notification template below.

### 5. Coordination
| Role | Name | Contact | Backup |
|------|------|----------|--------|
| Incident Lead | | | |
| Security | | | |
| Infrastructure | | | |
| Comms/Legal | | | |
| Product/CS | | | |

---

## AWS Console Procedures

### A. Isolate Edge VM
1. Go to **EC2 → Instances → Edge VM → Networking → Change security groups**.
2. Apply the `quarantine-no-egress` group and remove all others.
3. Confirm connectivity is blocked.

### B. Take Forensic Snapshots
1. **EC2 → Volumes → Select → Actions → Create Snapshot.**
2. Tag appropriately (`IncidentID`, `Owner=SecOps`).
3. Verify completion under **Snapshots**.

### C. Gather Logs
- **CloudWatch Logs → Log Groups** → export relevant log streams to the incident S3 bucket.
- **EC2 → Actions → Monitor and troubleshoot → Get system log** → download.

### D. Redeploy from Terraform Cloud
1. In GitHub, merge or trigger the Terraform Cloud workflow.
2. Open **Terraform Cloud → Workspaces → Edge VM Infra → Start Run → Apply**.
3. Verify new instance deployed and healthy.

---

## Communication Templates

**Initial Notice**
> *Subject:* Incident Declared — Edge VM  
> A suspected incident was detected on the Edge VM.  
> - Actions: containment via Security Groups, forensic snapshots taken.  
> - Next Update: every 60 minutes.  
> - Contact: Incident Lead (Name).

---

## Post-Incident Tasks
- Conduct RCA (Root Cause Analysis) within 5 business days.
- Document action items and assign owners.
- Delete forensic snapshots per retention policy.
- Rotate all secrets and API keys.
