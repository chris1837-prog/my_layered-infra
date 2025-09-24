# Database Access Runbook

## Overview
This document describes the procedures for accessing production databases.

## Access Methods

### PgBouncer Access (Adriana section)
**Note:** PgBouncer is configured for loopback-only access (127.0.0.1:6432) for enhanced 
security.

### Human Access via SSH Tunnel (Alicia section)
This method is for engineers who need temporary direct access to the database.
The tunnel forwards a local port on your machine to the database through the bastion and 
application VM.

#### 1. Open the SSH Tunnel
Run this command (replace variables with real values):

```bash
ssh -J admin@${BASTION_HOST} admin@${APP_VM_HOSTNAME} \
  -L 6432:127.0.0.1:6432 -N
