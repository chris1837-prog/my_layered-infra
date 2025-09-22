data "aws_ssm_parameter" "ubuntu" {
  # Lookup Ubuntu AMI from SSM (keeps AMI up to date automatically)
  name = local.ubuntu_ssm_path
}

resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = var.instance_type   # default = t3.medium (good balance for small DB + app)
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.sg_app_id]
  iam_instance_profile   = try(var.appdb_instance_profile_name, null)

  # Ensure user_data is re-run on changes (important for cloud-init/docker updates)
  user_data_replace_on_change = true
  user_data_base64            = data.cloudinit_config.app.rendered

  # Enable CloudWatch detailed monitoring (1-min granularity instead of 5-min)
  monitoring    = var.enable_monitoring
  # Ensure instance is optimized for EBS performance (on t3.* and newer it’s free)
  ebs_optimized = var.enable_ebs_optimized

  root_block_device {
    # Size of root volume (default 20GB) – holds OS + Docker volumes
    volume_size = var.ebs_volume_size
    # Volume type ( gp3 - cheaper + faster than gp2, baseline 3000 IOPS included)
    volume_type = var.ebs_volume_type
    encrypted   = true

    # For now: delete volume when instance is destroyed (stateless app design).
    # ⚠️ If persistence for database is required, set this to false or attach a separate volume.
    delete_on_termination = var.delete_on_termination
  }

  tags = merge(
    { Name = "${var.project_name}-${var.environment}-appdb-instance" },
    local.merged_tags
  )
}

data "cloudinit_config" "app" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      project_name               = var.project_name
      environment                = var.environment
      docker_compose_content     = file("${path.module}/../../mvp-compose/docker-compose.yml")
      app_image_name             = var.app_image_name  # e.g. "myorg/myapp" or just "myapp"
      internal_registry_url_path = var.ssm_internal_registry_url_path
      app_image_tag_path         = var.ssm_app_image_tag_path
      postgres_user_path         = var.ssm_postgres_user_path
      postgres_password_path     = var.ssm_postgres_password_path
      postgres_db_path           = var.ssm_postgres_db_path
      registry_user_path         = var.ssm_registry_user_path     # used if login required, comment out if not
      registry_password_path     = var.ssm_registry_password_path # used if login required, comment out if not
    })
  }
}

