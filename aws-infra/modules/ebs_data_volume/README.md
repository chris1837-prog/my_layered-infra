# EBS Data Volume Module

Creates a dedicated EBS volume for PostgreSQL data and (optionally) attaches it to a single EC2 instance. The module is intentionally small so it can be reused both for single-instance hosts and for launch-template/Auto Scaling patterns where attachment happens elsewhere.

## Features
- Opinionated tagging (`Project`, `Env`, `Role=postgres-data`) with optional overrides.
- Optional attachment to one or more instances via `attach_to_instances`.
- Defaults to encrypted `gp3` volumes but all major tuning knobs are exposed.

## Example
```hcl
module "pg_data_volume" {
  source = "github.com/webeet-io/layered-infra/aws-infra/modules/ebs_data_volume"

  project           = "layered"
  env               = "qa"
  availability_zone = "eu-central-1a"

  size_gb     = 100
  type        = "gp3"
  encrypted   = true
  kms_key_id  = null
  iops        = null
  throughput  = null

  device_name = "/dev/xvdb"
  attach_to_instances = {
    primary = aws_instance.single_host.id
  }
  tags = { Owner = "Squad-C" }
}
```

> See `examples/basic_usage` for a complete, self-contained setup (VPC, EC2,
> and volume attachment) that you can run in a sandbox account.

When using a launch template / Auto Scaling Group, leave `attach_to_instances`
empty and map the volume in the launch template instead.
