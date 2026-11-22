terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

# plan_only = true lets reviewers run init/validate/plan with NO AWS credentials.
# Set plan_only = false (and use real credentials) for an actual deployment.
provider "aws" {
  region = var.aws_region

  access_key = var.plan_only ? "mock-access-key" : null
  secret_key = var.plan_only ? "mock-secret-key" : null

  skip_credentials_validation = var.plan_only
  skip_requesting_account_id  = var.plan_only
  skip_metadata_api_check     = var.plan_only
  skip_region_validation      = var.plan_only

  default_tags {
    tags = {
      Project     = "hotel-bookings"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "hotel-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  name                 = local.name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  container_port       = var.container_port
  single_nat_gateway   = var.single_nat_gateway
}

module "rds" {
  source = "../../modules/rds"

  name                    = local.name
  subnet_ids              = module.network.private_subnet_ids
  security_group_id       = module.network.rds_sg_id
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_days
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = var.db_skip_final_snapshot
}

module "ecs" {
  source = "../../modules/ecs"

  name                    = local.name
  aws_region              = var.aws_region
  vpc_id                  = module.network.vpc_id
  public_subnet_ids       = module.network.public_subnet_ids
  private_subnet_ids      = module.network.private_subnet_ids
  alb_sg_id               = module.network.alb_sg_id
  ecs_sg_id               = module.network.ecs_sg_id
  container_image         = var.container_image
  container_port          = var.container_port
  task_cpu                = var.task_cpu
  task_memory             = var.task_memory
  desired_count           = var.desired_count
  log_retention_days      = var.log_retention_days
  alb_deletion_protection = var.alb_deletion_protection

  db_host       = module.rds.address
  db_port       = module.rds.port
  db_name       = module.rds.db_name
  db_secret_arn = module.rds.master_secret_arn
}
