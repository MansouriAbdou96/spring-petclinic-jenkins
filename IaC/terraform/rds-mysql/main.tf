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

resource "aws_db_instance" "mysql-db" {
  identifier              = "petclinic"
  engine                  = "mysql"
  engine_version          = "5.7.41"
  instance_class          = "db.t2.micro"
  db_name                 = "petclinic"
  username                = "petclinic"
  password                = "petclinic"
  parameter_group_name    = "default.mysql5.7"
  storage_encrypted       = false
  allocated_storage       = 20
  storage_type            = "gp2"
  backup_retention_period = 7
  multi_az                = false
  publicly_accessible     = true
  skip_final_snapshot = true
  vpc_security_group_ids  = [aws_security_group.mysqlSecGroup.id]

  tags = {
    Name        = "petclinic_db_mysql"
    Environment = "production"
  }
}

resource "aws_security_group" "mysqlSecGroup" {
  name_prefix = "mySQLSecGroup"
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "endpoint_url" {
  description = "the RDS MySQL endpoint URL"
  value       = aws_db_instance.mysql-db.endpoint
}
