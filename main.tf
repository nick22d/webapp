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

  ami = "ami-0302f42a44bf53a45"

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

# Create the EIP that will be associated with the NAT gateway
resource "aws_eip" "ngw" {
  domain   = "vpc"

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

# Crete the NAT gateway so that the private instances can communicate with the ALB
resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.ngw.id
  subnet_id     = aws_subnet.public_subnets[0].id

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}