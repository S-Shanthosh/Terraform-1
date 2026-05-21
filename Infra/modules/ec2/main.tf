resource "aws_key_pair" "shan" {
  key_name   = var.key_name
  public_key = file(pathexpand("~/.ssh/shanthosh-key.pub"))
}

resource "aws_instance" "ec2_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.shan.key_name
  subnet_id     = var.subnet_id
  tags          = { Name = var.instance_name }
}


