module "edge" {
  source = "../../modules/edge"
  # More coming here...
}

resource "aws_eip_association" "eip_assoc" {
  count = var.eip_allocation_id != null ? 1 : 0

  instance_id   = aws_instance.edge.id
  allocation_id = var.eip_allocation_id
}