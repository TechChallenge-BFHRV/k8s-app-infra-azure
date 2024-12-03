variable "orders-db_password" {
  type      = string
  sensitive = true
}

variable "orders-db_username" {
  type      = string
  sensitive = true
}

variable "resource_group_name" {
    type      = string
    sensitive = true
}

variable "resource_group_location" {
    type      = string
    sensitive = true
}

variable "kubernetes_cluster_name" {
    type      = string
    sensitive = true
}

variable "kubernetes_principal_id" {
  type = string
  sensitive = true
}