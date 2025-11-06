locals {
  # Detect architecture from instance type
  # ARM = Graviton families (t4g, m6g, c7g, etc.), otherwise AMD64
  arch = can(regex(".*g\\.", var.instance_type)) ? "arm64" : "amd64"

  # Build SSM parameter path dynamically
  ubuntu_ssm_path = "/aws/service/canonical/ubuntu/server/${var.ubuntu_version}/stable/current/${local.arch}/hvm/ebs-gp2/ami-id"

  # Render the nested templates here to avoid recursive calls
  docker_compose_obs_content = templatefile("${path.module}/templates/docker-compose.observability.yml.tftpl", {})

  promtail_config_edge_content = templatefile("${path.module}/templates/promtail-config-edge.yml.tftpl", {})

  prometheus_config_content = templatefile("${path.module}/templates/prometheus.yml.tftpl", {
    app_private_ip = var.app_private_ip
  })
}