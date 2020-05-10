variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "aws_key_name" {
  type = string
}

variable "aws_instance_type" {
  type    = string
  default = "t3.large"
}

variable "server_name" {
  type    = string
  default = "rust-dev"
}

variable "server_description" {
  type    = string
  default = "A benovolent dictatorship where nobody ever dies..."
}

variable "server_identity" {
  type    = string
  default = "rust-dev"
}

variable "server_seed" {
  type    = number
  default = 4242
}

variable "server_world_size" {
  type    = number
  default = 2000
}

variable "server_max_players" {
  type    = number
  default = 100
}
