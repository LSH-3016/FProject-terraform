variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "one"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.10.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.10.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.10.2.0/24", "10.10.20.0/24"]
}

variable "db_subnet_cidrs" {
  description = "Database subnet CIDR blocks"
  type        = list(string)
  default     = ["10.10.3.0/24", "10.10.30.0/24"]
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "oneuser"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  default     = "test1234"
  sensitive   = true
}

variable "ecr_repositories" {
  description = "List of ECR repository names"
  type        = list(string)
  default     = [
    "auth-api",
    "library-api",
    "journal-api",
    "stt-api",
    "image-generator-api"
  ]
}
