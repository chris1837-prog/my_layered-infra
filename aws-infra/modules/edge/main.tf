data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "edge" {
  name_prefix = "${var.project_name}-${var.environment}-edge-sg-"
  description = "Security group for the Edge VM"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP for redirects and Lets Encrypt"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow HTTPS for Caddy"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH from admin IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }
  ingress {
    description = "Allow WireGuard VPN from admin IPs"
    from_port   = var.wireguard_port
    to_port     = var.wireguard_port
    protocol    = "udp"
    cidr_blocks = var.admin_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Dynamic SSH Key Generation ---
resource "tls_private_key" "edge" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "edge" {
  key_name   = "${var.project_name}-${var.environment}-edge-key"
  public_key = tls_private_key.edge.public_key_openssh
}

# Save private key locally for admin use
resource "local_file" "edge_private_key" {
  content         = tls_private_key.edge.private_key_pem
  filename        = abspath("${path.module}/edge_private_key.pem")
  file_permission = "0600"
}


resource "aws_instance" "edge" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.edge.id]
  source_dest_check           = false
  key_name                    = aws_key_pair.edge.key_name

  user_data_replace_on_change = true
  user_data_base64 = data.cloudinit_config.edge.rendered
}

resource "aws_eip" "edge" {
  instance = aws_instance.edge.id
  domain   = "vpc"
}

data "cloudinit_config" "edge" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      admin_user      = var.admin_user
      admin_ssh_keys  = [tls_private_key.edge.public_key_openssh]
      domain_name     = var.domain_name
      backend_servers = var.backend_servers
      admin_cidrs     = var.admin_cidrs
      wireguard_port  = var.wireguard_port
    })
  }
}