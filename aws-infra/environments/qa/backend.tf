terraform {
  backend "s3" {
    bucket = "layered-infra-qa-tf-state-1e23675c"
    dynamodb_table = "layered-infra-qa-tf-locks"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
  }
}
