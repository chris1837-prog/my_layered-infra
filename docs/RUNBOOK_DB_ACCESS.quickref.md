# Database Access Runbook

---

## Human Access via SSH Tunnel

This method is for engineers who need temporary direct access to the database.  
The tunnel forwards a local port on your machine to the database through the bastion and application VM.

### 1. Open the SSH Tunnel
Run this command (replace variables with real values):

```bash
ssh -J admin@${BASTION_HOST} admin@${APP_VM_HOSTNAME} \
  -L 6432:127.0.0.1:6432 -N
