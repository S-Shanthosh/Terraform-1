resource "aws_vpc" "shan_vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.environment}-vpc" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.shan_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
  tags = { Name = "${var.environment}-public-subnet" }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.shan_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "ap-south-1a"
  tags = { Name = "${var.environment}-private-subnet" }
}

resource "aws_internet_gateway" "shan_igw" {
  vpc_id = aws_vpc.shan_vpc.id
  tags   = { Name = "${var.environment}-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.shan_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.shan_igw.id
  }
  tags = { Name = "${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public_rt_asn" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
