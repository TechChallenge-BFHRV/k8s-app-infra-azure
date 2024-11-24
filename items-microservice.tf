variable "items-db_username" {
  description = "The database username"
  type        = string
  sensitive   = true
}

variable "items-db_password" {
  description = "The database password"
  type        = string
  sensitive   = true
}

# Kubernetes Deployment
resource "kubernetes_deployment" "techchallenge_items_microservice" {
  metadata {
    name = "techchallenge-items-microservice"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "techchallenge-items-microservice"
      }
    }

    template {
      metadata {
        labels = {
          app = "techchallenge-items-microservice"
        }
      }

      spec {
        automount_service_account_token = false

        container {
          name  = "techchallenge-k8s"
          image = "viniciusdeliz/techchallenge-items-microservice:main"

          port {
            container_port = 3000
          }

          env {
            name  = "DATABASE_URL"
            value = "postgresql://${var.items-db_username}:${var.items-db_password}@postgres:5432/techchallenge?schema=public"
          }

          resources {
            requests = {
              cpu = "1m"
            }
          }
        }
      }
    }
  }
}

# Kubernetes Service
resource "kubernetes_service" "techchallenge_items_microservice" {
  metadata {
    name = "techchallenge-items-microservice"

    labels = {
      app = "techchallenge-items-microservice"
    }
  }

  spec {
    selector = {
      app = "techchallenge-items-microservice"
    }

    port {
      protocol    = "TCP"
      port        = 3000
      target_port = 3000
    }

    type = "ClusterIP"
  }
}