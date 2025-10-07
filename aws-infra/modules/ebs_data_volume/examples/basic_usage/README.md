# C5 Area 1 Postgres Data Volume (Example)

This example shows how to provision the Postgres data EBS volume that backs the
`layered_qa` (C5 Area 1) environment by consuming the `ebs_data_volume` module
directly. It mirrors the workflow we iterate on in that account, but keeps all
of the configuration inside the module’s `examples/` tree so it can double as
living documentation and an integration test harness.

## Why keep this example here?

- Re-uses the shared `layered_qa` bootstrap stack instead of re-running the
  bootstrap Terraform.
- Lets us test incremental changes in isolation before promoting them to the
  real environment.
- Keeps Terraform state/backend files generated during experiments out of the
  main repo (use this directory as your scratch space).

## Usage

```bash
cd aws-infra/modules/ebs_data_volume/examples/basic_usage
cp terraform.tfvars.example terraform.tfvars   # customise the values
terraform init
terraform plan
# terraform apply   # only run against the layered_qa account
```

Set `postgres_host_instance_id` to the EC2 instance that should receive the new
volume. Leave it unset when you only need the volume resource (for example,
when wiring it into an Auto Scaling Group launch template).

## Verification (layered_qa)

1. `terraform apply` and capture the `pg_data_volume_id` output.
2. SSH into the target host and run  
   `sudo DEVICE=<device> MOUNTPOINT=/var/lib/postgresql/data ./mvp-compose/ops/mount-postgres-ebs.sh`.
3. Restart the Compose stack (`docker compose up -d`), insert the sentinel row,
   restart Postgres, and confirm the row survives (`SELECT * FROM sentinel`).
4. Record the volume ID and tags for downstream snapshot/runbook work.

## Clean-up

When you are done testing:

```bash
terraform destroy
```

The bootstrap resources in the account remain untouched; this example only
creates (and optionally attaches) the Postgres data disk.
