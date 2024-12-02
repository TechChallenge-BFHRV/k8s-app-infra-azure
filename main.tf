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

  backend "s3" {
    bucket = "techchallenge-4-nestapp-terraform-state1"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
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

module "main-application" {
  source = "./modules/main-application"
  db_password = var.db_password
  db_username = var.db_username
  aws_api_gateway_id = data.aws_api_gateway_rest_api.example.id
  aws_region_name = data.aws_region.current.name
  aws_api_gateway_stage_name = aws_api_gateway_stage.example.stage_name
  aws_db_instance_addess = data.aws_db_instance.database.address
}

module "checkout-microservice" {
  source = "./modules/checkout-microservice"
  mongo_uri = var.mongo_uri
}

module "items-microservice" {
  source = "./modules/items-microservice"
  items-db_username = var.items-db_username
  items-db_password = var.items-db_password
  resource_group_name = azurerm_resource_group.example.name
  resource_group_location = azurerm_resource_group.example.location
  kubernetes_cluster_name = azurerm_kubernetes_cluster.example.name
  kubernetes_principal_id = azurerm_kubernetes_cluster.example.identity[0].principal_id
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
  authorization = "AWS_IAM"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.example.id
  rest_api_id   = data.aws_api_gateway_rest_api.example.id
}

resource "aws_api_gateway_method" "example2" {
  authorization = "AWS_IAM"
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
  xray_tracing_enabled = true
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



resource "aws_api_gateway_resource" "nest-api" {
  parent_id   = data.aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "{proxy+}"
  rest_api_id = data.aws_api_gateway_rest_api.example.id
}

resource "aws_api_gateway_method" "nest-get-method" {
  rest_api_id   = data.aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.nest-api.id
  http_method   = "ANY"
  authorization = "AWS_IAM"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id = data.aws_api_gateway_rest_api.example.id
  resource_id = aws_api_gateway_resource.nest-api.id
  http_method = aws_api_gateway_method.nest-get-method.http_method
  type        = "HTTP_PROXY"
  uri         = "http://${module.main-application.k8s-main-app-service-public-address}:3001/{proxy}"
  integration_http_method = "ANY"
  cache_key_parameters = ["method.request.path.proxy"]
  timeout_milliseconds = 29000
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

output "k8s_service_ip" {
  value = module.main-application.k8s-main-app-service-public-address
}
