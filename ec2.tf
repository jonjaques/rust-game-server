data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "random_password" "password" {
  length = 24
}


resource "tls_private_key" "admin" {
  algorithm = "RSA"
}

resource "aws_key_pair" "admin" {
  key_name   = "${var.server_name}-key"
  public_key = tls_private_key.admin.public_key_pem
}

data "template_file" "user_data" {
  template = file("templates/user_data.tpl")
  vars = {
    server_name = var.server_name
    password    = random_password.password.result
  }
}

resource "aws_instance" "rust" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.aws_instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2_describe_volumes_profile.name
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.rust.id]
  user_data              = data.template_file.user_data.rendered
  availability_zone      = var.availability_zone
  tags = {
    Name = var.server_name
  }
}
