variable "aws_region" {
  description = "The AWS region to create resources in"
  type        = string
  default     = "eu-west-3"
}

# VPC IP address
variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type = string
    default = "10.0.0.0/16"
}

# Subnets IP addresses
variable "subnet_cidrs" {
    description = "CIDR blocks for the subnets"
    type = list(string)
    default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# Availability zones
variable "availability_zones" {
    description = "Availability zones for the subnets"
    type = list(string)
    default = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]

}

variable "ami_id" {
  description = "The AMI ID to use for the instances"
  type        = string
  default     = "ami-00c12345678910" # Replace with your desired AMI ID
}

variable "instance_type" {
  description = "The instance type to use for the instances"
  type        = string
  default     = "t2.micro"
  
}

variable "key_name" {
  description = "The key pair name to use for the instances"
  type        = string
  default     = "my-key-pair" # Replace with your key pair name
  
}