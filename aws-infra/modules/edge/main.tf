data "aws_ssm_parameter" "ubuntu" {
  name = local.ubuntu_ssm_path
}

resource "random_password" "registry" {   # maybe not
  length  = 20
  special = true
}

resource "aws_ssm_parameter" "registry_password" {
  name        = local.registry_password_ssm_path
  type        = "SecureString"
  value       = local.registry_password_final
  description = "Docker registry password for Edge"
}

resource "aws_ssm_parameter" "registry_user" {
  name        = local.registry_user_ssm_path
  type        = "String"
  value       = var.registry_user
  description = "Docker registry username for Edge"
} # till here maybe not

resource "aws_route53_zone" "registry_private" {
  name   = var.registry_zone_name
  comment = "Private zone for Docker registry"
  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "registry" {
  zone_id = aws_route53_zone.registry_private.zone_id
  name    = var.registry_domain
  type    = "A"
  ttl     = 300
  records = [aws_instance.edge.private_ip]
}

resource "aws_instance" "edge" {
  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.sg_edge_id]
  source_dest_check      = false
  key_name               = var.key_name
  iam_instance_profile   = try(var.iam_instance_profile_name, null)

  user_data_replace_on_change = true
  user_data_base64            = data.cloudinit_config.edge.rendered

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-edge-instance"
  })
}

resource "aws_eip" "edge" {
  instance = aws_instance.edge.id
  domain   = "vpc"
}

data "cloudinit_config" "edge" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      admin_user        = var.admin_user,
      admin_ssh_keys    = var.admin_ssh_keys,
      domain_name       = var.domain_name,
      backend_servers   = var.backend_servers,
      admin_cidrs       = var.admin_cidrs,
      wireguard_port    = var.wireguard_port,
      registry_domain   = var.registry_domain,
      registry_user     = var.registry_user,
      registry_password = local.registry_password_final,
      bcrypt_hash       = local.bcrypt_hash
    })
  }
}