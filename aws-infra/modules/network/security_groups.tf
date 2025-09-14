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
  description = "Controls traffic for the private App VM. Only allows connections from Edge SG on the application port."
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
  ip_protocol       = var.tcp_protocol
  from_port         = var.https_port
  to_port           = var.https_port
  cidr_ipv4         = var.open_internet_cidr
}

# Allow HTTP from the public internet to Caddy (for redirects)
resource "aws_vpc_security_group_ingress_rule" "edge_http" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow HTTP from the internet to Caddy (for redirects)"
  ip_protocol       = var.tcp_protocol
  from_port         = var.http_port
  to_port           = var.http_port
  cidr_ipv4         = var.open_internet_cidr
}

# Allow WireGuard VPN traffic from admin devices
resource "aws_vpc_security_group_ingress_rule" "edge_wireguard" {
  for_each          = toset(var.allowed_admin_cidrs)
  security_group_id = aws_security_group.edge.id
  description       = "Allow WireGuard UDP traffic from ${each.value} admin devices"
  ip_protocol       = var.udp_protocol
  from_port         = var.wireguard_port
  to_port           = var.wireguard_port
  cidr_ipv4         = each.value
}

# Allow SSH access for management
resource "aws_vpc_security_group_ingress_rule" "edge_ssh" {
  for_each          = toset(var.allowed_admin_cidrs)
  security_group_id = aws_security_group.edge.id
  description       = "Allow SSH from ${each.value} for management"
  ip_protocol       = var.tcp_protocol
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  cidr_ipv4         = each.value
}

# =============================================================================
# INGRESS RULES for App SG
# =============================================================================

# Allow app traffic (port 3000) only FROM the Edge security group
# This is the core rule enabling Journey A (Web Traffic)
resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id            = aws_security_group.app.id
  description                  = "Allow HTTP app traffic from Edge SG"
  ip_protocol                  = var.tcp_protocol
  from_port                    = var.application_port
  to_port                      = var.application_port
  referenced_security_group_id = aws_security_group.edge.id
}

# =============================================================================
# EGRESS RULES
# =============================================================================

# Allow all outbound traffic from the Edge VM
resource "aws_vpc_security_group_egress_rule" "edge_egress" {
  security_group_id = aws_security_group.edge.id
  description       = "Allow all outbound traffic from Edge VM"
  ip_protocol       = var.all_protocols
  cidr_ipv4         = var.open_internet_cidr
}

# App SG Egress (Allow all outbound)
resource "aws_vpc_security_group_egress_rule" "app_egress_all" {
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound traffic"
  ip_protocol       = var.all_protocols
  cidr_ipv4         = var.open_internet_cidr
}
