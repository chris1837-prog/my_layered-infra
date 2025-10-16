terraform {
  backend "s3" {
    bucket         = "layered-infra-qa-tf-state-1c40b5b3"
    dynamodb_table = "layered-infra-qa-tf-locks"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
  }
}
