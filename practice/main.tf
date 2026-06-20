

provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "practice-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "practice-vpc"
  }
}

resource "aws_key_pair" "shanthosh_key" {
  key_name   = "shanthosh-key"
  public_key = file("~/.ssh/shanthosh-key.pub")
}

resource "aws_security_group" "practice_sg" {
  name        = "practice-sg"
  description = "Allow SSH"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "practice-ec2" {
  ami                    = "ami-0f58b397bc5c1f2e8"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.shanthosh_key.key_name
  vpc_security_group_ids = [aws_security_group.practice_sg.id]
  tags = {
    Name  = "practice-ec2"
    Owner = "Shanthosh"
    App   = "practice-app"
  }
}