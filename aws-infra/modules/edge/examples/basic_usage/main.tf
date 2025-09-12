provider "aws" {
  region  = "eu-central-1"
  profile = "edge"
}
resource "aws_key_pair" "edge_admin" {
  key_name   = "edge-admin"
  public_key = file("~/.ssh/edge-key.pub")
}

module "edge" {
  source        = "../../"
  ami           = "ami-0a116fa7c861dd5f9"  # x86_64 Ubuntu 24.04 LTS
  instance_type = "t3.micro"
  admin_cidrs   = ["95.91.249.11/32"]
  domain        = "example.com"
  app_private_ip = "10.0.1.10"
  app_port      = 8080
  key_pair_name = aws_key_pair.edge_admin.key_name
}
