data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical (official Ubuntu images)
}


#Instance Profile 

module "elk_vm_iam" {
  source = "../../modules/iam"
  project_name = var.project_name
  environment  = var.environment
  common_tags  = local.common_tags

  tf_state_bucket = local.bootstrap_outputs.tf_state_bucket_name
  lock_table      = local.bootstrap_outputs.tf_state_lock_table
}

#aws-security-group 

resource "aws_security_group" "elk_vm_sg" {
  name        = "elk-vm-sg"
  description = "Security group for ELK VM"
  vpc_id      = module.network.vpc_id

  ingress {
    description     = "Filebeat/Logstash access from Edge and App"
    from_port       = 5044
    to_port         = 5044
    protocol        = "tcp"
    security_groups = [module.network.sg_edge_id, module.network.sg_app_id]
  }

  ingress {
    description     = "Kibana access from Edge only"
    from_port       = 5601
    to_port         = 5601
    protocol        = "tcp"
    security_groups = [module.network.sg_edge_id]
  }

  ingress {
    description     = "Elasticsearch access from Edge only"
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [module.network.sg_edge_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ELK VM EC2 Instance

resource "aws_instance" "obs_elk_vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.large"
  subnet_id              = module.network.private_subnet_ids[0]
  key_name               = aws_key_pair.generated_key.key_name
  iam_instance_profile   = module.elk_vm_iam.ec2_instance_profile_name
  vpc_security_group_ids = [aws_security_group.elk_vm_sg.id]

  user_data = file("${path.module}/cloud-init-elk.tpl")

  tags = {
    Name = "obs-elk-vm"
    Role = "elk"
  }
}

#cloud-init/user_data requirements: 
#Install Docker (Docker Engine) and Docker Compose plugin (or docker-compose v2).