variable "db_username" {
  description = "The database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "The database password"
  type        = string
  sensitive   = true
}
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.116.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.example.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
}

data "aws_region" "current" {}

data "aws_api_gateway_rest_api" "example" {
  name = "techchallenge-api-gateway"
}

resource "aws_api_gateway_resource" "example" {
  parent_id   = data.aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "retrieve"
  rest_api_id = data.aws_api_gateway_rest_api.example.id
}

resource "aws_api_gateway_resource" "create-user" {
  parent_id   = data.aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "create"
  rest_api_id = data.aws_api_gateway_rest_api.example.id
}

resource "aws_api_gateway_method" "example" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.example.id
  rest_api_id   = data.aws_api_gateway_rest_api.example.id
}

resource "aws_api_gateway_method" "example2" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.create-user.id
  rest_api_id   = data.aws_api_gateway_rest_api.example.id
}

data "aws_lambda_function" "existing_lambda" {
  function_name = "read-user-from-cognito-userpool"
}
output "lambda_arn" {
  value = data.aws_lambda_function.existing_lambda.arn
}

data "aws_lambda_function" "existing_lambda2" {
  function_name = "create-user-in-cognito-userpool"
}
output "lambda_arn2" {
  value = data.aws_lambda_function.existing_lambda2.arn
}
resource "aws_api_gateway_integration" "example" {
  http_method = aws_api_gateway_method.example.http_method
  resource_id = aws_api_gateway_resource.example.id
  rest_api_id = data.aws_api_gateway_rest_api.example.id
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri = data.aws_lambda_function.existing_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "example2" {
  http_method = aws_api_gateway_method.example2.http_method
  resource_id = aws_api_gateway_resource.create-user.id
  rest_api_id = data.aws_api_gateway_rest_api.example.id
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri = data.aws_lambda_function.existing_lambda2.invoke_arn
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = data.aws_api_gateway_rest_api.example.id
  depends_on  = [aws_api_gateway_integration.proxy_integration]
  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.example.id,
      aws_api_gateway_method.example.id,
      aws_api_gateway_integration.example.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example.id
  rest_api_id   = data.aws_api_gateway_rest_api.example.id
  stage_name    = "dev"
}

# Create a resource group
resource "azurerm_resource_group" "example" {
  name     = "example-resource-techchallenge"
  location = "Australia Central"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "example" {
  name                = "example-network-techchallenge"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_kubernetes_cluster" "example" {
  name                = "example-aks1-techchallenge"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "exampleaks1"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.example.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.example.kube_config_raw

  sensitive = true
}

data "aws_db_instance" "database" {
  db_instance_identifier = "postgres-db"
}

resource "kubernetes_deployment" "techchallenge_k8s" {
  metadata {
    name = "techchallenge-k8s"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "techchallenge-k8s"
      }
    }

    template {
      metadata {
        labels = {
          app = "techchallenge-k8s"
        }
      }

      spec {
        container {
          name  = "techchallenge-k8s"
          image = "viniciusdeliz/techchallenge-k8s:main"

          port {
            container_port = 3001
          }
          env {
            name  = "ITEMS_SERVICE_HOST"
            value = "techchallenge-items-microservice"
          }

          env {
            name  = "ITEMS_SERVICE_PORT"
            value = "3000"
          }

          env {
            name  = "DATABASE_URL"
            value = "postgresql://${var.db_username}:${var.db_password}@${data.aws_db_instance.database.address}:5432/techchallenge?schema=public"
          }

          env {
            name  = "API_GATEWAY_URL"
            value = "https://${data.aws_api_gateway_rest_api.example.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.example.stage_name}"
          }
        }
      }
    }
  }
}



resource "kubernetes_service" "techchallenge_k8s" {
  metadata {
    name = "techchallenge-k8s"
  }

  spec {
    selector = {
      app = "techchallenge-k8s"
    }

    port {
      protocol    = "TCP"
      port        = 3001
      target_port = 3001
    }

    type = "LoadBalancer"
  }
}

output "k8s_service_ip" {
  value = kubernetes_service.techchallenge_k8s.status[0].load_balancer[0].ingress[0].ip
}

resource "kubernetes_deployment" "redis" {
  metadata {
    name = "redis"
    labels = {
      app = "redis"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis"
        }
      }

      spec {
        container {
          name  = "redis"
          image = "redis:latest"

          port {
            container_port = 6379
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    name = "redis"
  }

  spec {
    selector = {
      app = "redis"
    }

    port {
      port        = 6379
      target_port = 6379
    }

    type = "ClusterIP"
  }
}

resource "aws_api_gateway_resource" "nest-api" {
  parent_id   = data.aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "{proxy+}"
  rest_api_id = data.aws_api_gateway_rest_api.example.id
}

resource "aws_api_gateway_method" "nest-get-method" {
  rest_api_id   = data.aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.nest-api.id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id = data.aws_api_gateway_rest_api.example.id
  resource_id = aws_api_gateway_resource.nest-api.id
  http_method = aws_api_gateway_method.nest-get-method.http_method
  type        = "HTTP_PROXY"
  uri         = "http://${kubernetes_service.techchallenge_k8s.status[0].load_balancer[0].ingress[0].ip}:3001/{proxy}"
  integration_http_method = "ANY"
  cache_key_parameters = ["method.request.path.proxy"]
  timeout_milliseconds = 29000
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}
