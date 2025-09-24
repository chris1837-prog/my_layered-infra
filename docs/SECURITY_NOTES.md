
---

## 📄 `docs/SECURITY_NOTES.md`

Add or extend with this content:

```markdown
## mTLS Design & Certificate Rotation

### Why mTLS?
- Ensures **mutual authentication**: the database validates the client identity, and the client validates the database server.
- Stronger security posture than password-only connections.
- Prevents unauthorized services from reusing stolen credentials.

### Certificate Rotation & Renewal
- All client certificates are issued by the internal CA.
- Certificates must be rotated on a fixed schedule (e.g., every 90 days).
- Rotation process:
  1. Issue new certificate + private key.
  2. Deploy to `/etc/pgbouncer/tls/` on the proxy host.
  3. Reload pgbouncer or restart dependent service to pick up the new cert.
- Expired certificates will immediately block service access.

### Limitations (Proxy Host Only)
- mTLS access is explicitly scoped to the **proxy host**.
- No other hosts can connect directly to the database using mTLS.
- This restriction reduces the attack surface and ensures that all traffic flows through a single, controlled entry point.
