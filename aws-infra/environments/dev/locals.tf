locals {
  bootstrap_outputs = jsondecode(file("${path.module}/artifacts/bootstrap_outputs.json"))
  ssm_parameters    = jsondecode(file("${path.module}/artifacts/ssm_parameters.json"))

  edge_config = {
    eip_allocation_id   = local.bootstrap_outputs.edge_eip_allocation_id
    private_ip          = local.bootstrap_outputs.edge_private_ip
    parameter_paths     = {
      registry_password = local.ssm_parameters.parameter_paths.registry_password
    }
    parameter_values = {
      registry_url  = local.ssm_parameters.parameter_values.registry_url
      registry_user = local.ssm_parameters.parameter_values.registry_user
    }
  }

  appdb_config = {
    parameter_paths = {
      postgres_password = local.ssm_parameters.parameter_paths.postgres_password
      registry_password = local.ssm_parameters.parameter_paths.registry_password
      app_image_tag     = local.ssm_parameters.parameter_paths.app_image_tag
    }
    parameter_values = {
      registry_url  = local.ssm_parameters.parameter_values.registry_url
      registry_user = local.ssm_parameters.parameter_values.registry_user
      postgres_db   = local.ssm_parameters.parameter_values.postgres_db
      postgres_user = local.ssm_parameters.parameter_values.postgres_user
      app_image_tag = local.ssm_parameters.parameter_values.app_image_tag
    }
  }
}
