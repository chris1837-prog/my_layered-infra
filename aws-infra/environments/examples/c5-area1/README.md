# C5 Area 1 (layered_qa example)

Isolated Terraform sample that provisions the Postgres data EBS volume inside the `layered_qa` account. It is safe to iterate here without touching the shared stacks.

## Usage
```bash
cp terraform.tfvars.example terraform.tfvars  # edit instance/KMS values
terraform init
terraform plan
# terraform apply   # run only in layered_qa for testing
```

Set `postgres_host_instance_id` to the EC2 that should get the data disk. Leave it empty when you only need the volume object (e.g. ASG launch template flow).

## Verification (layered_qa)
1. `terraform apply` and note the `pg_data_volume_id` output.
2. SSH into the target host and run `sudo DEVICE=<device> MOUNTPOINT=/var/lib/postgresql/data ./mvp-compose/ops/mount-postgres-ebs.sh`.
3. Restart the Compose stack (`docker compose up -d`), run the sentinel insert, restart Postgres, and confirm the row survives (`SELECT * FROM sentinel`).
4. Capture the volume ID + tags for snapshot runbooks (Area 2) once verified.

## Clean Up
After verifying the mount + sentinel test:
```bash
terraform destroy
```
Bootstrapping resources in the account stay untouched; this example only creates the data disk (and attachment if requested).
