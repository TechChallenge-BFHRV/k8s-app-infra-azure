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
            name  = "CHECKOUT_SERVICE_HOST"
            value = "techchallenge-checkout-microservice"
          }

          env {
            name  = "CHECKOUT_SERVICE_PORT"
            value = "3002"
          }

          env {
            name  = "DATABASE_URL"
            value = "postgresql://${var.db_username}:${var.db_password}@${var.aws_db_instance_addess}:5432/techchallenge?schema=public"
          }

          env {
            name  = "API_GATEWAY_URL"
            value = "https://${var.aws_api_gateway_id}.execute-api.${var.aws_region_name}.amazonaws.com/${var.aws_api_gateway_stage_name}"
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

output "k8s-main-app-service-public-address" {
  description = "Main NestJS application public IP"
  value = kubernetes_service.techchallenge_k8s.status[0].load_balancer[0].ingress[0].ip
}