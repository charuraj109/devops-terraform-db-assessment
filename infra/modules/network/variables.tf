variable "name" {
  description = "Name prefix for all network resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones (one per subnet)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs of public subnets (ALB, NAT)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs of private subnets (ECS, RDS)"
  type        = list(string)
}

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 80
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheaper, for dev) instead of one per AZ"
  type        = bool
  default     = true
}
