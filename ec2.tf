module "ami" {
  source = "./modules/ami"
}

resource "aws_cloudwatch_log_group" "logs" {
  name = var.server_name
}

resource "random_password" "password" {
  length = 24
}

data "template_file" "user_data" {
  template = file("templates/cloud-init.yaml.tpl")
  vars = {
    region             = var.aws_region
    server_name        = var.server_name
    server_description = var.server_description
    server_identity    = var.server_identity
    server_seed        = var.server_seed
    server_world_size  = var.server_world_size
    server_max_players = var.server_max_players
    password           = random_password.password.result
  }
}

resource "aws_instance" "rust" {
  ami                         = module.ami.image_id
  ebs_optimized               = true
  associate_public_ip_address = true
  availability_zone           = local.availability_zone

  instance_type          = var.aws_instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2_describe_volumes_profile.name
  key_name               = var.aws_key_name
  vpc_security_group_ids = [aws_security_group.rust.id]
  user_data              = data.template_file.user_data.rendered

  tags = {
    Name        = var.server_name
    Description = var.server_description
  }

  depends_on = [
    aws_cloudwatch_log_group.logs
  ]
}

locals {
  instance_hostname = aws_instance.rust.public_dns
  instance_ip       = aws_instance.rust.public_ip
}
