environment = "prod"
aws_region  = "ap-south-1"
plan_only   = true # set to false for a real deployment with real credentials

# Network
azs                  = ["ap-south-1a", "ap-south-1b"]
vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
single_nat_gateway   = false # one NAT per AZ: no single point of failure

# ECS / Fargate sizing (larger, HA)
container_image         = "nginx:1.27-alpine"
container_port          = 80
task_cpu                = 1024
task_memory             = 2048
desired_count           = 3
log_retention_days      = 90
alb_deletion_protection = true

# RDS (larger, Multi-AZ, long retention, protected)
db_instance_class        = "db.t3.large"
db_allocated_storage     = 100
db_max_allocated_storage = 500
db_multi_az              = true
db_backup_retention_days = 14
db_deletion_protection   = true
db_skip_final_snapshot   = false
