Port 6432 (PgBouncer) isn’t restricted for the proxy host (mTLS path)
In your runbook/task, the design explicitly allows:

Human access only via SSH tunnel (loopback 127.0.0.1 → no SG rule needed ✅).

Service access via mTLS from the proxy host only.

In this SG, there is no rule allowing tcp/6432 from the proxy host’s SG.

❌ Result: your services will fail to reach PgBouncer, even with mTLS certs.

Egress is overly permissive
You allow all outbound traffic (0.0.0.0/0, protocol = -1).

This is AWS’s default, but for DB instances, least-privilege is better:

Postgres usually only needs outbound to application VMs, maybe monitoring, backup services.

Right now, if something compromises your DB, it can call out anywhere.

⚠️ Governance / audit might flag this.

Ingress depends on SG references only
You correctly scoped 22 to the bastion SG and 5432 to the app SG. ✅

But if someone mistakenly adds app servers to the wrong SG, they’d get DB access.

Safer: restrict with both SG + CIDR constraints (e.g. app subnet
CIDR).

Missing description inside rules
Terraform lets you add description per ingress rule.

Without it, AWS console shows just ports/protocols. Harder to audit later.

Example:

ingress {
description = "Postgres from app servers"
from_port = 5432
to_port = 5432
protocol = "tcp"
security_groups = [aws_security_group.app_sg.id]

resource "aws_security_group" "db_sg" {
name = "db-security-group"
description = "Security group for database instances"
tags = {
Name = "db-security-group"
Environment = "prod"
}

SSH access from bastion only
ingress {
description = "SSH from bastion"
from_port = 22
to_port = 22
protocol = "tcp"
security_groups = [aws_security_group.bastion_sg.id]
}

Postgres access from application instances only
ingress {
description = "Postgres from app servers"
from_port = 5432
to_port = 5432
protocol = "tcp"
security_groups = [aws_security_group.app_sg.id]
}

PgBouncer (mTLS path) access from proxy host only
ingress {
description = "PgBouncer mTLS from proxy host"
from_port = 6432
to_port = 6432
protocol = "tcp"
security_groups = [aws_security_group.proxy_sg.id]
}

Egress: consider narrowing to only necessary destinations
egress {
from_port = 0
to_port = 0
protocol = "-1"
# Example: restrict to app subnet + proxy host if required
# cidr_blocks = ["10.0.1.0/24", "${proxy_host_ip}/32"]
cidr_blocks = ["0.0.0.0/0"] # temporary/all-purpose
}
}



SG is functionally correct for the task.

The main “problem” is the overly permissive egress and reliance purely on SG references (good to tighten for compliance).

Adding tags improves manageability.

                +-------------------+
                |   Bastion Host    |
                |   SG: bastion_sg  |
                +---------+---------+
                          |
                          | TCP/22 (SSH)
                          v
+---------------------------------------------------+
|                DB Security Group (db_sg)          |
|                                                   |
|  +----------------+    +----------------+         |
|  | App Instances  |    |   Proxy Host   |         |
|  | SG: app_sg     |    | SG: proxy_sg   |         |
|  +-------+--------+    +--------+-------+         |
|          |                    |                   |
|          | TCP/5432 (Postgres)|                   |
|          v                    v                   |
|   [ Database Instance(s) / PgBouncer ]            |
|                                                   |
|    * Port 22 open only from bastion_sg            |
|    * Port 5432 open only from app_sg              |
|    * Port 6432 open only from proxy_sg (mTLS)     |
|    * No open ingress from anywhere else           |
|    * Egress: ALL (currently 0.0.0.0/0, -1)        |
+---------------------------------------------------+



What this enforces

Human admins must come through Bastion → SSH tunnel → DB (never direct).

Applications can talk to Postgres (5432) but not PgBouncer directly.

Proxy host can talk to PgBouncer (6432, mTLS only).

Nobody else can touch the DB.

⚠️ Weak spot

The only “loose” rule is egress = all (0.0.0.0/0).

If the DB was compromised, it could call out to the internet.

Often narrowed to VPC/private subnets (e.g. 10.0.0.0/16) or specific services (backups, monitoring).


what to consider:

1.Egress tightening (recommended)

Default (0.0.0.0/0) means DB can talk to the whole internet.

Often reduced to:

VPC CIDR only (e.g. 10.0.0.0/16)

Or specific SGs (monitoring, backup agent hosts).
egress {
description = "Allow internal traffic only"
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["10.0.0.0/16"]
}

Outbound DNS/updates (if needed)
If your DB needs package updates or DNS resolution, allow outbound 53 (DNS) or 443 (patching repos) specifically.

Otherwise, block it for tighter lockdown.

3.VPC/Subnet firewall alignment

Ensure NACLs (if used) don’t contradict SG rules.

SGs are stateful, NACLs are stateless — if both are enforced, check consistency.

4.Auditing & tagging

Add tags like Owner, Environment, Compliance.

Helps with audits and Terraform drift checks.

Future-proofing (mTLS expansion)
Right now, PgBouncer mTLS is proxy-only.

If the team later decides to expand mTLS to multiple services, you’ll need to add more ingress rules for those SGs.

Good to comment this in the code so it’s clear this SG is scoped to proxy host by design.

6.Cross-account / external risks

Ensure aws_security_group.proxy_sg.id doesn’t include unintended hosts (like if proxy SG is reused for other VMs).

One trick: create a dedicated SG just for the proxy host, so you’re not sharing it.


✅ What you already did

Ingress least-privilege:

Port 22 only from Bastion SG.

Port 5432 only from App SG.

Port 6432 only from Proxy SG (mTLS only).

No accidental public access to DB ports.

Documented rules (good for audits).

That covers 95% of what a DB SG needs in this architecture.

🔍 What else you might consider (depends on org requirements)

Egress rules

Current config: 0.0.0.0/0 (open to the internet).

Safer: restrict to VPC CIDR or specific SGs (e.g. monitoring, backup agents).

Granular ingress descriptions

You already added description fields — that’s excellent for compliance.

Sometimes teams also add tags (Environment, Owner, Compliance=PCI) so the SG is traceable.

Cross-account trust

If your infra spans multiple AWS accounts, make sure you aren’t accidentally allowing an SG from a different account unless intended.

Rotation / expansion

Right now 6432 is proxy only. If later more hosts need PgBouncer, rules will need revisiting.

Good to note in comments:

“mTLS is scoped to proxy host only by design — do not expand without security review.”

NACL alignment (optional)

If you’re using VPC Network ACLs in addition to SGs, double-check they’re not conflicting (SGs = stateful, NACLs = stateless).

(Human Admin)
Laptop
   |
   | (1) WireGuard VPN
   v
Edge VM
   |
   | (2) SSH Tunnel -> localhost:6432
   v
App VM (Private Subnet, behind SG: allow 22 from Bastion, 5432 from App SG only)
   |
   | (3) PgBouncer (loopback only) -- Unix socket -->
   v
Postgres (SG: allow 5432 from App SG, 6432 only from Proxy SG, 22 only from Bastion SG)
   |
   | (4) Outbound restricted: only within VPC (no Internet)
   v
[Monitoring / Backup systems inside VPC only]






Things to consider:
tightening egress,
tagging for audits,
documenting future scope.