
variable "alertmanager_slack_url" {
  type        = string
  default     = ""
  description = "Slack webhook url for metric alerts"
}

variable "alertmanager_slack_channel" {
  type        = string
  default     = "rust-notifications"
  description = "The channel to post metric alerts to"
}

variable "aws_region" {
  type        = string
  default     = "us-east-2"
  description = "The AWS region to deploy in"
}

variable "aws_key_name" {
  type        = string
  description = "The AWS key pair to use"
}

variable "aws_instance_type" {
  type        = string
  default     = "t3.large"
  description = "The AWS instance to use"
}

variable "grafana_password" {
  type        = string
  default     = "admin"
  description = "The grafana admin password"
}

variable "rust_server_startup_arguments" {
  type        = string
  default     = "-batchmode -load -nographics +server.secure 1"
  description = "rust"
}

variable "rust_server_identity" {
  type        = string
  default     = "docker"
  description = "rust"
}

variable "rust_server_seed" {
  type        = number
  default     = 12345
  description = "rust"
}

variable "rust_server_name" {
  type        = string
  default     = "Rust Server [DOCKER]"
  description = "rust"
}

variable "rust_server_description" {
  type        = string
  default     = "This is a Rust server running inside a Docker container"
  description = "rust"
}

variable "rust_server_url" {
  type        = string
  default     = "https://hub.docker.com/r/didstopia/rust-server/"
  description = "rust"
}

variable "rust_server_banner_url" {
  type        = string
  default     = ""
  description = "rust"
}

variable "rust_rcon_web" {
  type        = bool
  default     = true
  description = "rust"
}

variable "rust_rcon_port" {
  type        = number
  default     = 28016
  description = "rust"
}

variable "rust_rcon_password" {
  type        = string
  default     = "docker"
  description = "rust"
}

variable "rust_update_checking" {
  type        = bool
  default     = true
  description = "rust"
}

variable "rust_update_branch" {
  type        = string
  default     = "public"
  description = "rust"
}

variable "rust_start_mode" {
  type        = number
  default     = 0
  description = "rust"
}

variable "rust_oxide_enabled" {
  type        = bool
  default     = true
  description = "rust"
}

variable "rust_oxide_update_on_boot" {
  type        = bool
  default     = true
  description = "rust"
}

variable "rust_server_worldsize" {
  type        = number
  default     = 3500
  description = "rust"
}

variable "rust_server_maxplayers" {
  type        = number
  default     = 500
  description = "rust"
}

variable "rust_server_save_interval" {
  type        = number
  default     = 600
  description = "rust"
}
