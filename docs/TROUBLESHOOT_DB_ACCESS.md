
# Troubleshooting DB Access

This guide covers common problems when connecting to the database via **SSH tunnel** (human access) or **mTLS** (service access through proxy host).

---

## 1. SSH Tunnel Issues

### Tunnel Fails to Open
- Check bastion host reachability:
  ```bash
  ping ${BASTION_HOST}
Run SSH with verbose logging
ssh -vvv -J admin@${BASTION_HOST} admin@${APP_VM_HOSTNAME}
Verify your SSH key is loaded in the agent:
ssh-add -l
Connection Refused on 6432

Confirm the tunnel is active:

lsof -i :6432
Check firewall rules on bastion/VM.

Ensure PgBouncer is running on the target host.


2. mTLS Issues (Proxy Host Only)

Certificate Errors

CN/SAN mismatch (hostnames don’t match):
openssl x509 -in /etc/pgbouncer/tls/client.crt -noout -text

Check the Subject and Subject Alternative Name fields.

Expired certificate:
openssl x509 -in /etc/pgbouncer/tls/client.crt -noout -dates

Wrong CA:
Ensure you’re using the correct ca.crt that signed the server cert.
Example Debug Command

Test the TLS connection manually:

openssl s_client -connect ${PROXY_HOST_WG_IP}:6432 \
  -CAfile /etc/pgbouncer/tls/ca.crt \
  -cert /etc/pgbouncer/tls/client.crt \
  -key /etc/pgbouncer/tls/client.key

3. PgBouncer / Service Issues
Connection Refused or Reset

Check PgBouncer is running:

systemctl status pgbouncer

Confirm it’s listening on port 6432:
netstat -tulnp | grep 6432
Firewall Blocks

Verify the firewall on the proxy host allows port 6432:
sudo iptables -L -n | grep 6432

sudo iptables -L -n | grep 6432

General Tips

Always verify which path you’re testing:

Human = SSH tunnel + 127.0.0.1:6432

Service = Proxy host + mTLS + ${PROXY_HOST_WG_IP}:6432

Use psql -v ON_ERROR_STOP=1 to fail fast on errors.

For intermittent issues, check logs:

SSH: /var/log/auth.log

PgBouncer: /var/log/pgbouncer/pgbouncer.log