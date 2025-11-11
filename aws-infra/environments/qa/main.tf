# layered-infra/aws-infra/environments/qa/main.tf

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# --- SSH Key Pair ---
resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.project_name}-${var.environment}-instance-key" # e.g., layered-infra-qa-instance-key
  public_key = tls_private_key.instance_key.public_key_openssh
}

resource "local_file" "ssh_private_key" {
  content         = tls_private_key.instance_key.private_key_pem
  filename        = "${path.module}/${aws_key_pair.generated_key.key_name}.pem"
  file_permission = "0600"
}

# --- IAM Module ---
# Call the IAM module to create roles needed by EC2 instances
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags

  # Get backend info dynamically from the backend configuration
  tf_state_bucket = local.bootstrap_outputs.tf_state_bucket_name
  lock_table      = local.bootstrap_outputs.tf_state_lock_table

  # Add any other required inputs for the IAM module
}

# --- Network Module ---
module "network" {
  source = "../../modules/network"

  vpc_cidr            = "10.0.0.0/16" # Or use a variable
  allowed_admin_cidrs = var.allowed_admin_cidrs

  az_configurations = {
    (data.aws_availability_zones.available.names[0]) = {
      public_subnet_cidr  = "10.0.1.0/24"
      private_subnet_cidr = "10.0.2.0/24"
    }
    (data.aws_availability_zones.available.names[1]) = {
      public_subnet_cidr  = "10.0.101.0/24"
      private_subnet_cidr = "10.0.102.0/24"
    }
  }

  project_name = var.project_name
  common_tags  = local.common_tags
}

# --- Edge Module ---
module "edge" {
  source = "../../modules/edge"

  # Pass project/environment directly from variables
  project_name = var.project_name
  environment  = var.environment

  # Network/Instance config
  vpc_id           = module.network.vpc_id
  public_subnet_id = module.network.public_subnet_ids[1] # switched from [0] to [1] for QA subnet alignment
  sg_edge_id       = module.network.sg_edge_id
  instance_type    = "t3.micro"
  key_name         = aws_key_pair.generated_key.key_name
  admin_ssh_keys   = [tls_private_key.instance_key.public_key_openssh]

  # EIP/IAM config
  enable_eip_association    = true
  eip_allocation_id         = local.bootstrap_outputs.edge_eip_allocation_id
  iam_instance_profile_name = module.iam.ec2_instance_profile_name

  # Cloud-init arguments - Fetch VALUES using data blocks
  admin_user            = "ubuntu"
  domain_name           = data.aws_ssm_parameter.edge_primary_url.value
  backend_servers       = ["${module.appdb.appdb_private_ip}:3000"]
  admin_cidrs           = var.allowed_admin_cidrs
  wireguard_port        = 51820
  registry_external_url = "https://${data.aws_ssm_parameter.external_registry_url_value.value}"
  registry_internal_url = "https://${data.aws_ssm_parameter.internal_registry_url_value.value}"
  registry_user         = data.aws_ssm_parameter.registry_user_value.value
  registry_password     = data.aws_ssm_parameter.registry_password_value.value
  app_private_ip        = local.appdb_private_ip
  # promtail_version      = var.promtail_version  # duplicate definition removed to prevent error
  # acme_email          = var.acme_email

  # Feature flags
  enable_acme_external = false
  enable_wireguard     = true
  enable_domain_tls    = false
  enable_domain_acme   = false

  # Observability
  promtail_version = var.promtail_version
  edge_private_ip  = "10.0.101.100"
}

# --- AppDB Module ---
module "appdb" {
  source = "../../modules/appdb"

  project_name = var.project_name
  environment  = var.environment

  private_subnet_id = module.network.private_subnet_ids[1] # switched from [0] to [1] for QA subnet alignment
  sg_app_id         = module.network.sg_app_id
  app_private_ip    = local.appdb_private_ip

  instance_type               = "t3.micro"
  key_pair_name               = aws_key_pair.generated_key.key_name
  appdb_instance_profile_name = module.iam.ec2_instance_profile_name
  db_volume_id                = module.db_volume.volume_id

  # Cloud-init SSM Parameter Paths
  ssm_internal_registry_url_path = local.appdb_config.parameter_paths.internal_registry_url
  ssm_registry_user_path         = local.appdb_config.parameter_paths.registry_user
  ssm_registry_password_path     = local.appdb_config.parameter_paths.registry_password
  ssm_postgres_db_path           = local.appdb_config.parameter_paths.postgres_db
  ssm_postgres_user_path         = local.appdb_config.parameter_paths.postgres_user
  ssm_postgres_password_path     = local.appdb_config.parameter_paths.postgres_password
  ssm_app_image_name_path        = local.appdb_config.parameter_paths.app_image_name
  ssm_app_image_tag_path         = local.appdb_config.parameter_paths.app_image_tag

  common_tags = local.common_tags

  # Observability
  promtail_version       = var.promtail_version
  docker_compose_content = file("../../../mvp-compose/docker-compose.yml")
  promtail_config_content = templatefile("../../modules/appdb/templates/promtail-config-app.yml.tftpl", {
    edge_private_ip = "10.0.101.100"
  })
  node_exporter_version = var.node_exporter_version
}

resource "aws_route" "private_to_edge_nat" {
  route_table_id         = module.network.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.edge.primary_network_interface_id
}

resource "aws_vpc_security_group_ingress_rule" "appdb_from_edge_node_exporter" {
  description = "Allow Prometheus on Edge to scrape Node Exporter on App (port 9100)"

  security_group_id = module.network.sg_app_id

  ip_protocol = "tcp"
  from_port   = 9100
  to_port     = 9100

  referenced_security_group_id = module.network.sg_edge_id
}

# --- EBS Volume for AppDB ---
module "db_volume" {
  source = "../../modules/ebs_data_volume"

  # Basic parameters
  project = var.project_name
  env     = var.environment

  # Volume configuration
  availability_zone = data.aws_availability_zones.available.names[1] # switched from [0] to [1] for QA subnet alignment
  size_gb           = 20
  type              = "gp3"
  encrypted         = true

  # Additional tags for identification and environment tracking
  tags = {
    Role        = "postgres-data"
    Environment = var.environment
  }

  # Attach this volume to the AppDB instance
  attach_to_instances = {
    appdb = module.appdb.appdb_instance_id
  }
}


