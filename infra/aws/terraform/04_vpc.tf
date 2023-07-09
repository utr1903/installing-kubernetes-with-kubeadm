###########
### VPC ###
###########

# VPC
resource "aws_vpc" "k8s" {
  cidr_block = "192.168.0.0/16"
}

# Gateway
resource "aws_internet_gateway" "k8s" {
  vpc_id = aws_vpc.k8s.id
}

# Subnet - master
resource "aws_subnet" "master" {
  vpc_id     = aws_vpc.k8s.id
  cidr_block = "192.168.0.0/24"

  depends_on = [aws_internet_gateway.k8s]
}

# Subnet - worker
resource "aws_subnet" "worker" {
  vpc_id     = aws_vpc.k8s.id
  cidr_block = "192.168.1.0/24"

  depends_on = [aws_internet_gateway.k8s]
}

# Route table to internet
resource "aws_route_table" "internet" {
  vpc_id = aws_vpc.k8s.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s.id
  }
}

# Route table to subnet assosiaction - master
resource "aws_route_table_association" "master" {
  subnet_id = aws_subnet.master.id
  route_table_id = aws_route_table.internet.id
}

# Route table to subnet assosiaction - worker
resource "aws_route_table_association" "worker" {
  subnet_id = aws_subnet.worker.id
  route_table_id = aws_route_table.internet.id
}
