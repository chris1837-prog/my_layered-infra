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



## Service Access via mTLS (Proxy Host Only)

This workflow is only valid when connecting from the **proxy host**.  
Connections must use **mutual TLS (mTLS)** to authenticate both the client and the server.  
Each service account has a corresponding TLS client certificate and private key.

### Connect with psql
From the proxy host, run:

```bash
psql "host=${PROXY_HOST_WG_IP} port=6432 dbname=${DB_NAME} user=svc_app \
  sslmode=verify-full \
  sslrootcert=/etc/pgbouncer/tls/ca.crt \
  sslcert=/etc/pgbouncer/tls/client.crt \
  sslkey=/etc/pgbouncer/tls/client.key" \
  -c 'select 1;'
