variable "availability_zone" {
  type    = string
  default = "us-east-2a"
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "aws_instance_type" {
  type    = string
  default = "t3.large"
}

variable "server_name" {
  type    = string
  default = "rust-dev"
}
