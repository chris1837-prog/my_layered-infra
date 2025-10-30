#Instance Profile 

module "elk_vm_iam" {
  source = "../../modules/iam"
  name   = "elk-vm-profile"
}

#aws-security-group 

resource "aws_security_group" "elk_vm_sg" {
  name        = "elk-vm-sg"
  description = "Security group for ELK VM"
  vpc_id      = module.network.vpc_id

  ingress {
    description     = "Filebeat/Logstash from Edge and App"
    from_port       = 5044
    to_port         = 5044
    protocol        = "tcp"
    security_groups = [aws_security_group.edge_sg.id, aws_security_group.app_sg.id]
  }

  ingress {
    description     = "Kibana & Elasticsearch from Edge only"
    from_port       = 5601
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [aws_security_group.edge_sg.id]
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
  key_name               = outputs.generated_key
  iam_instance_profile   = module.elk_vm_iam.instance_profile_name
  vpc_security_group_ids = [aws_security_group.elk_vm_sg.id]

  user_data = file("${path.module}/cloud-init-elk.tpl")

  tags = {
    Name = "obs-elk-vm"
    Role = "elk"
  }
}

#cloud-init/user_data requirements: 
#Install Docker (Docker Engine) and Docker Compose plugin (or docker-compose v2).
#Create /opt/elk/ and write docker-compose.elk.yml and logstash.conf. 
#Start docker compose