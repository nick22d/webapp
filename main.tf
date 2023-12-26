# Define the main terraform block
terraform {
  required_version = ">=1.6.6"
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

  default_cidr_block = "0.0.0.0/0"

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
  domain = "vpc"

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

# Crete the NAT gateway so that the private instances can communicate with the ALB
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.ngw.id
  subnet_id     = aws_subnet.public_subnets[0].id

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

# Create the security group for the ALB
resource "aws_security_group" "sg_for_alb" {
  name        = "sg_for_alb"
  description = "Allow HTTP traffic from the internet."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from the world"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [local.default_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.default_cidr_block]
  }

  tags = {
    Name = "sg_for_alb"
  }
}

# Create the security group for the EC2 fleet
resource "aws_security_group" "sg_for_ec2" {
  name        = "sg_for_ec2"
  description = "Allow HTTP traffic from the ALB."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from the ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_for_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.default_cidr_block]
  }

  tags = {
    Name = "sg_for_ec2"
  }
}

# Create the launch configuration for the ASG
resource "aws_launch_configuration" "launch_config" {
  image_id        = local.ami
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.sg_for_ec2.id]

  user_data = <<-EOF
        #!/bin/bash
        sudo yum update -y
        sudo yum install -y httpd
        sudo systemctl start httpd
        sudo systemctl enable httpd
        cd /var/www/html
        echo "<html>
        <head>
        <title>A two-tier architecture for a single-page application</title>
        <style>
        body {
        display: flex;
        align-items: center;
        justify-content: center;
        height: 100vh;
        margin: 0;
        font-family: Arial, sans-serif;
        background-color: black;
        color: white
        }
        </style>
        </head>
        <body>
        <h1>Security Charms</h1>
        </body>
        </html>" > index.html
        sudo systemctl restart httpd

    EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Create the ASG
resource "aws_autoscaling_group" "asg" {
  launch_configuration = aws_launch_configuration.launch_config.name
  min_size             = 4
  max_size             = 10

  vpc_zone_identifier = [aws_subnet.private_subnets[0].id, aws_subnet.private_subnets[1].id]

  target_group_arns = [aws_lb_target_group.lb_tg.arn]
}

# Create the ALB
resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_for_alb.id]
  subnets            = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id]

  enable_deletion_protection = false

  tags = {
    Environment = "alb"
  }
}

# Create the target group for the ALB
resource "aws_lb_target_group" "lb_tg" {
  name     = "tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}


# Create a listener for the ALB
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# Create a listener rule for the ALB
resource "aws_lb_listener_rule" "lb_rule" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg.arn
  }
}

# Create the route table for the public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route for internal communication
  route {
    cidr_block =  local.vpc_cidr_block
    gateway_id = "local"
  }
  # Default route to the IGW
  route {
    cidr_block = local.default_cidr_block
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Create the route table for the private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id 

  # Route for internal communication
  route {
    cidr_block =  local.vpc_cidr_block
    gateway_id = "local"
  }

  # Default route to the NAT GW
  route {
    cidr_block = local.default_cidr_block
    nat_gateway_id = aws_nat_gateway.ngw.id
  }


  tags = {
    Name = "PrivateRouteTable"
  }
}

# Create the association between the public route table and the public subnets
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public.id
}

# Create the association between the private route table and the private subnets
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = aws_route_table.private.id
}

# Create the public subnets
resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }

}

# Create the private subnets
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}
