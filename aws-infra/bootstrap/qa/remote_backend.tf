module "remote_backend" {
  source       = "../../modules/remote_backend"
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags
  bucket_name = "layered-infra-qa-tf-state-1e23675c"
}