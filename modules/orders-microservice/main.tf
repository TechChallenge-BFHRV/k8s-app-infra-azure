# Kubernetes Deployment
resource "kubernetes_deployment" "techchallenge_orders_microservice" {
  metadata {
    name = "techchallenge-orders-microservice"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "techchallenge-orders-microservice"
      }
    }

    template {
      metadata {
        labels = {
          app = "techchallenge-orders-microservice"
        }
      }

      spec {
        automount_service_account_token = false

        container {
          name  = "techchallenge-k8s"
          image = "viniciusdeliz/techchallenge-orders-microservice:main"

          port {
            container_port = 3000
          }

          env {
            name  = "DATABASE_URL"
            value = "postgresql://${var.orders-db_username}:${var.orders-db_password}@postgres:5432/techchallenge?schema=public"
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
resource "kubernetes_service" "techchallenge_orders_microservice" {
  metadata {
    name = "techchallenge-orders-microservice"

    labels = {
      app = "techchallenge-orders-microservice"
    }
  }

  spec {
    selector = {
      app = "techchallenge-orders-microservice"
    }

    port {
      protocol    = "TCP"
      port        = 3000
      target_port = 3000
    }

    type = "ClusterIP"
  }
}