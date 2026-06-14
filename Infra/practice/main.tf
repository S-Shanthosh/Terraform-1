provider "aws" {
region = "ap-south-1"
}


resource "aws_vpc" "practice-vpc" {
cidr_block = "10.0.0.0/16"
tags = {
    Name = "practice-vpc"
}
}