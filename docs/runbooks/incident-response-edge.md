# Incident Response Runbook — Edge VM

**Purpose:** Step-by-step actions for a suspected security incident on the Edge VM.

**When to use:** Any alerts, suspicious traffic, or compromise indicators on the Edge VM.

---

## The 5 C’s of Incident Response

### 1. Containment
- Isolate the Edge VM using a dedicated **Quarantine Security Group** in AWS (no ingress/egress).
- Stop public access via AWS Console → EC2 → Networking → Change Security Groups → select *quarantine-no-egress*.
- Do **not** reboot or terminate until evidence is captured.

### 2. Collection
- From AWS Console: **EC2 → Volumes → Create Snapshot** for each attached EBS volume.
- Tag snapshots with `IncidentID`, `Timestamp`, and `Owner`.
- Export CloudWatch and Caddy logs to S3 for retention.
- Record instance metadata (ID, AMI, SGs, IPs) in case notes.

### 3. Correction
- After evidence is preserved, **terminate** the compromised instance.
- **Redeploy** a clean instance through the Terraform Cloud workspace.
- Reattach standard Security Groups and rotate all secrets and credentials.

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
