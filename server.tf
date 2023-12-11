# Create the security group for the ALB
resource "aws_security_group" "sg_for_alb" {
    name        = "sg_for_alb"
  description = "Allow HTTP traffic from the internet."
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "HTTP from the world"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_for_alb"
  }
}