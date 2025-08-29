# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  route {
    cidr_block = var.open_internet_cidr
    gateway_id = var.igw_id
  }
  tags = merge({ Name = "${var.project_name}-public-rt" }, var.common_tags)
}

resource "aws_route_table_association" "public" {
  for_each       = var.public_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = var.vpc_id
  tags = merge({ Name = "${var.project_name}-private-rt" }, var.common_tags)
}

resource "aws_route_table_association" "private" {
  for_each       = var.private_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}