data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  name               = "${var.project_name}-${var.environment}-vpc"
  cidr               = "10.0.0.0/16"
  azs                = data.aws_availability_zones.available.names
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway = true
  enable_vpn_gateway = false
  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

resource "aws_security_group" "sg" {
  name   = "${var.project_name}-${var.environment}-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

module "ec2_instance" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  name                        = "${var.project_name}-${var.environment}-ec2"
  ami                         = "ami-093a7f5fbae13ff67"
  instance_type               = "t3.small"
  monitoring                  = true
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.sg.id]
  associate_public_ip_address = true
  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

resource "aws_security_group" "db" {
  name   = "${var.project_name}-${var.environment}-db-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "Allow EC2 access to PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
      aws_security_group.sg.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

module "db" {
  source                                  = "terraform-aws-modules/rds/aws"
  identifier                              = "demo-${var.project_name}-${var.environment}-db"
  engine                                  = "postgres"
  engine_version                          = "17.6"
  instance_class                          = "db.t3.micro"
  allocated_storage                       = 5
  db_name                                 = var.environment
  username                                = var.db_username
  manage_master_user_password             = true
  master_user_password_rotate_immediately = false
  port                                    = "5432"
  vpc_security_group_ids = [
    aws_security_group.db.id
  ]
  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets
  family                 = "postgres17"
  major_engine_version   = "17.7"
  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}
