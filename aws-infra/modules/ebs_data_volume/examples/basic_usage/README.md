# EBS Data Volume Module – Basic Usage Example

This self-contained scenario provisions:

- a throwaway VPC + subnet
- a security group and public EC2 instance to act as the Postgres host
- a dedicated data EBS volume attached via the `ebs_data_volume` module

It doubles as both documentation and an integration harness for future Terratest
runs, so no manual wiring (VPC IDs, instance IDs, etc.) is required.

## Usage

```bash
cd aws-infra/modules/ebs_data_volume/examples/basic_usage
terraform init
terraform plan
# terraform apply        # creates real infrastructure; use only in sandbox accounts
```

All inputs have sensible defaults; tweak them by copying `terraform.tfvars.example`
if you need to change instance type, region, CIDRs, etc.

## Verification Steps

1. `terraform apply` and capture the `pg_data_volume_id` output.
2. SSH into the host (the output `host_instance_id` plus the EC2 console will
   show the assigned public IP) and run  
   `sudo DEVICE=<device> MOUNTPOINT=/var/lib/postgresql/data ./mvp-compose/ops/mount-postgres-ebs.sh`.
3. Restart the Compose stack (`docker compose up -d`), insert the sentinel row,
   restart Postgres, and confirm the row survives (`SELECT * FROM sentinel`).
4. Record the volume ID and tags for downstream snapshot/runbook work.

## Clean-up

When you are done testing:

```bash
terraform destroy
```

This tears down the VPC, host, and volume so the example leaves no lingering
infrastructure behind.
