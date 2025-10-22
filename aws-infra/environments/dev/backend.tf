terraform {
  backend "s3" {
    bucket         = "layered-infra-dev-tf-state-c4b038b9"
    dynamodb_table = "layered-infra-dev-tf-locks"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
  }
}
