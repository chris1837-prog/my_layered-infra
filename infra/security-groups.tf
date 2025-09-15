# Security group for database instances
resource "aws_security_group" "db_sg" {
  name        = "db-security-group"
  description = "Security group for database instances"
  
  # SSH access from bastion only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
  
  # Postgres access from application instances only
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }
  
  # DB admin via SSH tunnel only; 6432 must not be exposed.
  # Note: No inbound rule for tcp/6432
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
