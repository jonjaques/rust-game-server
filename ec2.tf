module "ami" {
  source = "./modules/ami"
}

resource "aws_cloudwatch_log_group" "logs" {
  name = var.rust_server_identity
}

data "template_file" "user_data" {
  template = file("templates/cloud-init.yaml.tpl")
  vars = {
    # AWS Settings
    AWS_REGION = var.aws_region

    # Grafana settings
    GRAFANA_USER               = "admin"
    GRAFANA_PASSWORD           = var.grafana_password
    ALERTMANAGER_SLACK_URL     = var.alertmanager_slack_url
    ALERTMANAGER_SLACK_CHANNEL = var.alertmanager_slack_channel

    # Setup default environment variables for the server
    # ENV RUST_SERVER_STARTUP_ARGUMENTS "-batchmode -load -nographics +server.secure 1"
    RUST_SERVER_STARTUP_ARGUMENTS = var.rust_server_startup_arguments
    # ENV RUST_SERVER_IDENTITY "docker"
    RUST_SERVER_IDENTITY = var.rust_server_identity
    # ENV RUST_SERVER_SEED "12345"
    RUST_SERVER_SEED = tostring(var.rust_server_seed)
    # ENV RUST_SERVER_NAME "Rust Server [DOCKER]"
    RUST_SERVER_NAME = var.rust_server_name
    # ENV RUST_SERVER_DESCRIPTION "This is a Rust server running inside a Docker container!"
    RUST_SERVER_DESCRIPTION = var.rust_server_description
    # ENV RUST_SERVER_URL "https://hub.docker.com/r/didstopia/rust-server/"
    RUST_SERVER_URL = var.rust_server_url
    # ENV RUST_SERVER_BANNER_URL ""
    RUST_SERVER_BANNER_URL = var.rust_server_banner_url
    # ENV RUST_RCON_WEB "1"
    RUST_RCON_WEB = var.rust_rcon_web ? "1" : "0"
    # ENV RUST_RCON_PORT "28016"
    RUST_RCON_PORT = tostring(var.rust_rcon_port)
    # ENV RUST_RCON_PASSWORD "docker"
    RUST_RCON_PASSWORD = var.rust_rcon_password
    # ENV RUST_UPDATE_CHECKING "0"
    RUST_UPDATE_CHECKING = var.rust_update_checking ? "1" : "0"
    # ENV RUST_UPDATE_BRANCH "public"
    RUST_UPDATE_BRANCH = var.rust_update_branch
    # ENV RUST_START_MODE "0"
    RUST_START_MODE = tostring(var.rust_start_mode)
    # ENV RUST_OXIDE_ENABLED "0"
    RUST_OXIDE_ENABLED = var.rust_oxide_enabled ? "1" : "0"
    # ENV RUST_OXIDE_UPDATE_ON_BOOT "1"
    RUST_OXIDE_UPDATE_ON_BOOT = var.rust_oxide_update_on_boot ? "1" : "0"
    # ENV RUST_SERVER_WORLDSIZE "3500"
    RUST_SERVER_WORLDSIZE = tostring(var.rust_server_worldsize)
    # ENV RUST_SERVER_MAXPLAYERS "500"
    RUST_SERVER_MAXPLAYERS = tostring(var.rust_server_maxplayers)
    # ENV RUST_SERVER_SAVE_INTERVAL "600"
    RUST_SERVER_SAVE_INTERVAL = tostring(var.rust_server_save_interval)
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
    Name        = var.rust_server_identity
    Description = var.rust_server_name
  }

  depends_on = [
    aws_cloudwatch_log_group.logs
  ]
}

locals {
  instance_hostname = aws_instance.rust.public_dns
  instance_ip       = aws_instance.rust.public_ip
  rcon_port         = var.rust_rcon_port
  rcon_password     = var.rust_rcon_password
}
