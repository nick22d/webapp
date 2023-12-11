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
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
    cidr_blocks = ["0.0.0.0/0"]
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
        echo "<html><h1>This is my 1st server</h1></html>" > index.html
        sudo systemctl restart httpd

    EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Create the ASG
resource "aws_autoscaling_group" "asg" {
  launch_configuration = aws_launch_configuration.launch_config.name
  min_size             = 2
  max_size             = 10

  vpc_zone_identifier = [for subnet in aws_subnet.private_subnets : subnet.id]
}

# Create the ALB
resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_for_alb.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  enable_deletion_protection = false

  tags = {
    Environment = "alb"
  }
}

