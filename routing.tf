# Create the route table for the public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route for internal communication
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }
  # Default route to the IGW
  route {
    cidr_block = "0.0.0.0/0"
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
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
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
