environment = "dev"
aws_region  = "ap-south-1"
plan_only   = true

# Network
azs                  = ["ap-south-1a", "ap-south-1b"]
vpc_cidr             = "10.10.0.0/16"
public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24"]
private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24"]
single_nat_gateway   = true # one NAT: cheaper

# ECS / Fargate sizing (small)
container_image         = "nginx:1.27-alpine"
container_port          = 80
task_cpu                = 256
task_memory             = 512
desired_count           = 1
log_retention_days      = 7
alb_deletion_protection = false

# RDS (small, short retention, easy to tear down)
db_instance_class        = "db.t3.micro"
db_allocated_storage     = 20
db_max_allocated_storage = 50
db_multi_az              = false
db_backup_retention_days = 1
db_deletion_protection   = false
db_skip_final_snapshot   = true
