data "aws_ssm_parameter" "ubuntu" {
  name = local.ubuntu_ssm_path
}

resource "aws_instance" "edge" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.sg_edge_id]
  source_dest_check           = false
  key_name                    = var.key_name
  associate_public_ip_address = false
  private_ip                  = var.edge_private_ip
  iam_instance_profile        = try(var.iam_instance_profile_name, null)

  user_data_replace_on_change = true
  user_data_base64            = data.cloudinit_config.edge.rendered

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-edge-instance"
  })
}

resource "aws_eip_association" "eip_assoc" {
  count = var.enable_eip_association ? 1 : 0

  instance_id   = aws_instance.edge.id
  allocation_id = var.eip_allocation_id
}

# Cloud-init configuration for the edge instance
data "cloudinit_config" "edge" {
  gzip          = true
  base64_encode = true

  part {
    # Template is configured to expect direct values, not SSM parameter paths
    # When you want to call this module, you must resolve SSM parameters to values first or change the template config to accept paths
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      admin_user               = var.admin_user,
      admin_ssh_keys           = var.admin_ssh_keys,
      domain_name              = var.domain_name,
      backend_servers          = var.backend_servers,
      admin_cidrs              = var.admin_cidrs,
      wireguard_port           = var.wireguard_port,
      registry_external_url    = var.registry_external_url,
      registry_internal_url    = var.registry_internal_url,
      registry_user            = var.registry_user,
      registry_password        = var.registry_password,
      enable_acme_external     = var.enable_acme_external,
      acme_email               = var.acme_email,
      enable_wireguard         = var.enable_wireguard,
      enable_domain_tls        = var.enable_domain_tls,
      enable_domain_acme       = var.enable_domain_acme,
    })
  }
}
