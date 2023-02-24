terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.17"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

variable "AMItoUse" {
  type        = string
  description = "ami to use for the petclinic server"
}
variable "buildID" {
  type        = string
  description = "jenkins Build ID"
}

resource "aws_security_group" "petclinicSecGroup" {
  description = "Allowing port 8080 and 22"
  name        = "petclinicSecGroup-${var.buildID}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "petclinic_server" {
  ami           = var.AMItoUse
  instance_type = "t2.micro"
  key_name      = "petclinic"

  security_groups = [aws_security_group.petclinicSecGroup.name]

  tags = {
    "Name" = "petclinic-Instance-${var.buildID}"
  }
}

output "petclinic-ip" {
  description = "Public IP of the petclinic server"
  value       = aws_instance.petclinic_server.public_ip
}

output "petclinic-dns" {
  description = "DNS of the petclinic server"
  value       = aws_instance.petclinic_server.public_dns
}
