locals {
  bootstrap_outputs = jsondecode(file("${path.module}/artifacts/bootstrap_outputs.json"))
  ssm_parameters    = jsondecode(file("${path.module}/artifacts/ssm_parameters.json"))

  edge_config = {
    project_name            = local.bootstrap_outputs.project_name
    environment             = local.bootstrap_outputs.environment
    aws_region              = local.bootstrap_outputs.aws_region
    eip_allocation_id       = local.bootstrap_outputs.edge_eip_allocation_id
    edge_private_ip         = local.bootstrap_outputs.edge_private_ip
    parameter_paths = {
      external_registry_url = local.ssm_parameters.parameter_paths.external_registry_url
      internal_registry_url = local.ssm_parameters.parameter_paths.internal_registry_url
      registry_user         = local.ssm_parameters.parameter_paths.registry_user
      registry_password     = local.ssm_parameters.parameter_paths.registry_password

    }
  }

  appdb_config = {
    project_name            = local.bootstrap_outputs.project_name
    environment             = local.bootstrap_outputs.environment
    aws_region              = local.bootstrap_outputs.aws_region
    parameter_paths = {
      internal_registry_url = local.ssm_parameters.parameter_paths.internal_registry_url
      external_registry_url = local.ssm_parameters.parameter_paths.external_registry_url
      postgres_db           = local.ssm_parameters.parameter_paths.postgres_db
      postgres_user         = local.ssm_parameters.parameter_paths.postgres_user
      postgres_password     = local.ssm_parameters.parameter_paths.postgres_password
      app_image_name        = local.ssm_parameters.paramether_paths.app_image_name
      app_image_tag         = local.ssm_parameters.parameter_paths.app_image_tag
    }
  }
}
