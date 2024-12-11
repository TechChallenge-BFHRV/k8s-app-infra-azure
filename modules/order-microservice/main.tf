# Kubernetes Deployment
resource "kubernetes_deployment" "techchallenge_items_microservice" {
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
            container_port = 3003
          }

          env {
            name  = "ORDER_DATABASE_URL"
            value = "postgresql://${var.order-db_username}:${var.order-db_password}@order-database-db:5432/orderdb?schema=public"
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
      port        = 3003
      target_port = 3003
    }

    type = "ClusterIP"
  }
}