// Provider
provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

// Look up the default VPC
data "aws_vpc" "default" {
  default = true
}

// Look up a subnet in the target AZ
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = [var.a-zone]
  }
}

// ============================================================
//  EC2 #1 — Jenkins Master
// ============================================================
resource "aws_instance" "jenkins_master" {
  subnet_id              = data.aws_subnets.default.ids[0]
  ami                    = var.ami-id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_master_sg.id]

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 15
    volume_type = "gp2"
    tags = {
      "name" = "root disk"
    }
  }

  tags = {
    Name = "Jenkins-Master"
  }

  user_data = file("files/install_jenkins_master.sh")
}

// ============================================================
//  EC2 #2 — Jenkins Agent (with Docker)
// ============================================================
resource "aws_instance" "jenkins_agent" {
  subnet_id              = data.aws_subnets.default.ids[0]
  ami                    = var.ami-id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_agent_sg.id]

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 15
    volume_type = "gp2"
    tags = {
      "name" = "root disk"
    }
  }

  tags = {
    Name = "Jenkins-Agent"
  }

  # Pass the master's private IP so the agent script knows where to connect
  user_data = templatefile("files/install_jenkins_agent.sh", {
    master_ip = aws_instance.jenkins_master.private_ip
  })
}


// ============================================================
//  Security Group — Jenkins Master
// ============================================================
resource "aws_security_group" "jenkins_master_sg" {
  name        = "JenkinsMasterSG"
  description = "SG for Jenkins Master - web UI from my IP, agent traffic on 80"
  vpc_id      = data.aws_vpc.default.id
}

// SSH from my IP
resource "aws_security_group_rule" "master_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip]
  security_group_id = aws_security_group.jenkins_master_sg.id
  description       = "SSH from my IP"
}

// Jenkins Web UI (port 80) from my IP
resource "aws_security_group_rule" "master_http_my_ip" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip]
  security_group_id = aws_security_group.jenkins_master_sg.id
  description       = "Jenkins UI from my IP"
}

// Jenkins port 80 from the agent SG (JNLP / agent.jar traffic)
resource "aws_security_group_rule" "master_http_from_agent" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_agent_sg.id
  security_group_id        = aws_security_group.jenkins_master_sg.id
  description              = "Jenkins agent - master on port 80"
}

// ICMP ping from anywhere (handy for debugging)
resource "aws_security_group_rule" "master_icmp" {
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_master_sg.id
  description       = "Allow ping"
}

// Egress — allow all
resource "aws_security_group_rule" "master_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_master_sg.id
}


// ============================================================
//  Security Group — Jenkins Agent
// ============================================================
resource "aws_security_group" "jenkins_agent_sg" {
  name        = "JenkinsAgentSG"
  description = "SG for Jenkins Agent - SSH from my IP, traffic from master"
  vpc_id      = data.aws_vpc.default.id
}

// SSH from my IP
resource "aws_security_group_rule" "agent_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip]
  security_group_id = aws_security_group.jenkins_agent_sg.id
  description       = "SSH from my IP"
}

// Allow all traffic from the master SG (Jenkins master → agent comms)
resource "aws_security_group_rule" "agent_from_master" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins_master_sg.id
  security_group_id        = aws_security_group.jenkins_agent_sg.id
  description              = "All TCP from Jenkins master"
}

// ICMP ping
resource "aws_security_group_rule" "agent_icmp" {
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_agent_sg.id
  description       = "Allow ping"
}

// Egress — allow all
resource "aws_security_group_rule" "agent_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_agent_sg.id
}


// ============================================================
//  Outputs
// ============================================================
output "jenkins_master_public_ip" {
  value       = aws_instance.jenkins_master.public_ip
  description = "Public IP of Jenkins Master - open http://<this-ip> in browser"
}

output "jenkins_agent_public_ip" {
  value       = aws_instance.jenkins_agent.public_ip
  description = "Public IP of Jenkins Agent (SSH access)"
}

output "jenkins_master_private_ip" {
  value       = aws_instance.jenkins_master.private_ip
  description = "Private IP of Jenkins Master (used by agent)"
}
