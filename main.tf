# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
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

resource "aws_api_gateway_rest_api" "example" {
  name = "techchallenge-api-gateway"
}

resource "aws_api_gateway_resource" "example" {
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "retrieve"
  rest_api_id = aws_api_gateway_rest_api.example.id
}

resource "aws_api_gateway_resource" "create-user" {
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "create"
  rest_api_id = aws_api_gateway_rest_api.example.id
}

resource "aws_api_gateway_method" "example" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.example.id
  rest_api_id   = aws_api_gateway_rest_api.example.id
}

resource "aws_api_gateway_method" "example2" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.create-user.id
  rest_api_id   = aws_api_gateway_rest_api.example.id
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
  rest_api_id = aws_api_gateway_rest_api.example.id
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri = data.aws_lambda_function.existing_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "example2" {
  http_method = aws_api_gateway_method.example2.http_method
  resource_id = aws_api_gateway_resource.create-user.id
  rest_api_id = aws_api_gateway_rest_api.example.id
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri = data.aws_lambda_function.existing_lambda2.invoke_arn
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id

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
  rest_api_id   = aws_api_gateway_rest_api.example.id
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
    vm_size    = "Standard_D2_v2"
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