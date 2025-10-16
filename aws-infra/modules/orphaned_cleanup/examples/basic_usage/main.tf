provider "aws" {
  region = "eu-central-1"
}

module "orphaned_cleanup" {
  source        = "../.."
  function_name = "qa-orphaned-ebs-cleanup"
}