# Security group for database instances
resource "aws_security_group" "db_sg" {
  name        = "db-security-group"
  description = "Security group for database instances"
  vpc_id      = var.vpc_id

  # SSH access from bastion only
  ingress {
    description     = "SSH from bastion host(s) only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Postgres access from application instances only
  ingress {
    description     = "Postgres from application servers only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  # PgBouncer (mTLS path) access from proxy host only
  ingress {
    description     = "PgBouncer mTLS from proxy host (scoped by design)"
    from_port       = 6432
    to_port         = 6432
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy_sg.id]
  }

  # Egress: restricted to VPC only (no internet)
  # Adjust if DB needs outbound traffic to monitoring/backup services
  egress {
    description = "Allow outbound traffic only within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr] # Example: "10.0.0.0/16"
  }

  tags = {
    Name        = "db-security-group"
    Owner       = "platform-team"
    Environment = var.environment
    Compliance  = "PCI" # Adjust to your org's compliance labels
  }
}