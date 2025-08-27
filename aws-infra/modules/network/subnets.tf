# --- Public Subnets ---

resource "aws_subnet" "public" {
  # Loop over the az_configurations map
  for_each = var.az_configurations

  vpc_id                  = var.vpc_id
  availability_zone       = each.key # key is the AZ name (e.g. "eu-central-1a")
  cidr_block              = each.value.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = merge({ Name = "${var.project_name}-public-subnet-${each.key}" }, var.common_tags)
}

# --- Private Subnets ---

resource "aws_subnet" "private" {
  # Loop directly over the az_configurations map
  for_each = var.az_configurations

  vpc_id            = var.vpc_id
  availability_zone = each.key
  cidr_block        = each.value.private_subnet_cidr

  tags = merge({ Name = "${var.project_name}-private-subnet-${each.key}" }, var.common_tags)
}