# =============================================================================
# security_groups.tf
# =============================================================================

# Security Group for the public Edge VM
resource "aws_security_group" "edge" {
  name        = "${var.project_name}-edge-sg"
  description = "Controls traffic for the public Edge VM (Caddy & WireGuard)."
  vpc_id      = aws_vpc.this.id

  tags = merge(
    { Name = "${var.project_name}-edge-sg" },
    var.common_tags
  )
}

# Security Group for the private App VM
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Controls traffic for the private App VM. Only allows connections from Edge SG on port 3000."
  vpc_id      = aws_vpc.this.id

  tags = merge(
    { Name = "${var.project_name}-app-sg" },
    var.common_tags
  )
}

# =============================================================================
# INGRESS RULES for Edge SG
# =============================================================================

# Allow HTTPS from the public internet to Caddy
resource "aws_vpc_security_group_ingress_rule" "edge_https" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow HTTPS from the internet to Caddy"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# Allow HTTP from the public internet to Caddy (for redirects)
resource "aws_vpc_security_group_ingress_rule" "edge_http" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow HTTP from the internet to Caddy (for redirects)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# Allow WireGuard VPN traffic from admin devices
resource "aws_vpc_security_group_ingress_rule" "edge_wireguard" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow WireGuard UDP traffic from admin devices"
  ip_protocol       = "udp"
  from_port         = 51820
  to_port           = 51820
  cidr_ipv4         = var.wireguard_admin_cidr
}

# Allow SSH access for management
resource "aws_vpc_security_group_ingress_rule" "edge_ssh" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow SSH for management"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_admin_cidr
}

# =============================================================================
# INGRESS RULES for App SG
# =============================================================================

# Allow app traffic (port 3000) only FROM the Edge security group
# This is the core rule enabling Journey A (Web Traffic)
resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id            = aws_security_group.app.id
  description                  = "Allow HTTP app traffic from Edge SG"
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = aws_security_group.edge.id
}

# =============================================================================
# EGRESS RULES
# =============================================================================

# Allow all outbound traffic from the Edge VM
resource "aws_vpc_security_group_egress_rule" "edge_egress" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow all outbound traffic from Edge VM"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# The App SG intentionally has no egress rules