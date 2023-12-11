terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Define a list of local values for centralised reference
locals {
  region = "eu-west-3"

  vpc_cidr_block = "10.0.0.0/16"

  tags = {
    Name = "managedByTF"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = local.region
}

# Create the main VPC
resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr_block

  tags = local.tags
}

# Create the internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = local.tags

}