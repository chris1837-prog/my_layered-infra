# EBS Data Volume Module

Creates a dedicated EBS volume for PostgreSQL data and (optionally) attaches it to a single EC2 instance. The module is intentionally small so it can be reused both for single-instance hosts and for launch-template/Auto Scaling patterns where attachment happens elsewhere.

## Features
- Opinionated tagging (`Project`, `Env`, `Role=postgres-data`) with optional overrides.
- Optional attachment to an existing instance (`attach_to_instance_id`).
- Defaults to encrypted `gp3` volumes but all major tuning knobs are exposed.

## Example
```hcl
module "pg_data_volume" {
  source = "../../../modules/ebs_data_volume" # when called from environments/examples/*

  project               = "layered"
  env                   = "qa"
  availability_zone     = "eu-central-1a"
  size_gb               = 100
  attach_to_instance_id = aws_instance.single_host.id
}
```

When using a launch template / Auto Scaling Group, leave `attach_to_instance_id` unset and map the volume in the launch template instead.
