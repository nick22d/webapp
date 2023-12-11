# Define a variable for storing the CIDR blocks of the public subnets for easy iteration 
variable "public_subnet_cidrs" {
  description = "Public Subnet CIDR blocks."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# Define a variable for storing the CIDR blocks of the private subnets for easy iteration
variable "private_subnet_cidrs" {
  description = "Private Subnet CIDR blocks."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# Define a list of AZs
variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default = [
    "eu-west-3a",
    "eu-west-3b"
  ]
}