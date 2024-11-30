variable "db_username" {
    type = string
    sensitive = true
}

variable "db_password" {
    type = string
    sensitive = true
}

variable "aws_api_gateway_id" {
  type = string
  sensitive = true
}

variable "aws_region_name" {
    type = string
    sensitive = true
}

variable "aws_api_gateway_stage_name" {
  type = string
  sensitive = true
}

variable "aws_db_instance_addess" {
  type = string
  sensitive = true
}