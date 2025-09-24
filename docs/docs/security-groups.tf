resource "aws_security_group" "db_sg" {
  name        = "db-security-group"
  description = "Security group for database instances"

  # SSH access from bastion only
  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Postgres access from application instances only
  ingress {
    description = "Postgres from app servers"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  # PgBouncer (mTLS path) access from proxy host only
  ingress {
    description = "PgBouncer mTLS from proxy host"
    from_port   = 6432
    to_port     = 6432
    protocol    = "tcp"
    security_groups = [aws_security_group.proxy_sg.id]
  }

  # Egress (consider narrowing if compliance requires it)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
