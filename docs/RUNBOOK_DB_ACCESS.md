# Database Access Runbook

## Overview
This document describes the procedures for accessing production databases.

## Access Methods

### PgBouncer Access (Adriana section)
**Note:** PgBouncer is configured for loopback-only access (127.0.0.1:6432) for enhanced security.

### SSH Tunnel Access (Alicia section)
For detailed instructions on establishing SSH tunnels for database administration:

#### SSH Tunnel Command:
```bash
ssh -L 6432:127.0.0.1:6432 user@app-vm
