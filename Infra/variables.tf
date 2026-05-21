variable "vpc_cidr" {
  type = string
}
variable "public_subnet_cidr" {
  type = string
}
variable "private_subnet_cidr" {
  type = string
}
variable "environment" {
  type = string
}
variable "ami_id" {
  type = string
}
variable "instance_type" {
  type    = string
  default = "t2.micro"
}
variable "key_name" {
  type = string
}
variable "instance_name" {
  type = string
}
variable "bucket_name" {
  type = string
}

