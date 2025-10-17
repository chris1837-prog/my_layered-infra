provider "aws" {
  region = "eu-central-1"
}

# This one will FAIL (no Backup tag)
resource "aws_ebs_volume" "bad_volume" {
  availability_zone = "eu-central-1"
  size              = 1

  tags = {
    Name = "no-backup"
  }
}

# This one will PASS (has Backup tag)
resource "aws_ebs_volume" "good_volume" {
  availability_zone = "eu-central-1"
  size              = 1

  tags = {
    Name   = "has-backup"
    Backup = "daily"
  }
}

