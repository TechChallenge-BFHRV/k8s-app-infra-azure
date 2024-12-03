variable "mongo_uri" {
  type      = string
  sensitive = true
}

variable "items-db_password" {
  type      = string
  sensitive = true
}

variable "items-db_username" {
  type      = string
  sensitive = true
}
variable "orders-db_password" {
  type      = string
  sensitive = true
}

variable "orders-db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_username" {
  type      = string
  sensitive = true
}