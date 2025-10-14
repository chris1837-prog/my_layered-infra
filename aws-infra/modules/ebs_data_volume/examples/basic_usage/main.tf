# =============================================================================
# examples/basic_usage/main.tf
# Self-contained scenario that provisions a VPC, an EC2 host, and attaches
# the Postgres data volume via the ebs_data_volume module.
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  az = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])

  base_tags = merge(
    {
      Project = var.project
      Env     = var.env
    },
    var.additional_tags,
  )
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.base_tags, { Name = "${var.project}-${var.env}-pgdata-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, { Name = "${var.project}-${var.env}-pgdata-igw" })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = merge(local.base_tags, { Name = "${var.project}-${var.env}-pgdata-public" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, { Name = "${var.project}-${var.env}-pgdata-rt" })
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "host" {
  name        = "${var.project}-${var.env}-pgdata-sg"
  description = "Allow SSH for the Postgres data volume example host"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, { Name = "${var.project}-${var.env}-pgdata-sg" })
}

resource "aws_instance" "host" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.host.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  tags = merge(local.base_tags, { Name = "${var.project}-${var.env}-pgdata-host" })
}

module "pg_data_volume" {
  source = "../.."

  name              = "${var.project}-${var.env}-pg-data"
  project           = var.project
  env               = var.env
  availability_zone = local.az

  size_gb    = var.volume_size_gb
  type       = var.volume_type
  encrypted  = var.volume_encrypted
  kms_key_id = var.volume_kms_key_id
  iops       = var.volume_iops
  throughput = var.volume_throughput

  device_name = var.volume_device_name
  attach_to_instances = {
    host = aws_instance.host.id
  }

  tags = local.base_tags
}
