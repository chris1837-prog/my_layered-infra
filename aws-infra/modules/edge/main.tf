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

resource "aws_instance" "edge" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.edge.id]
  source_dest_check           = false
  iam_instance_profile        = aws_iam_instance_profile.edge.name

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
      admin_ssh_keys  = var.admin_ssh_keys
      domain_name     = var.domain_name
      backend_servers = var.backend_servers
      admin_cidrs     = var.admin_cidrs
      wireguard_port  = var.wireguard_port
    })
  }
}

resource "aws_iam_role" "edge" {
  name               = "${var.project_name}-${var.environment}-edge-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.edge.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "edge" {
  name = "${var.project_name}-${var.environment}-edge-profile"
  role = aws_iam_role.edge.name
}