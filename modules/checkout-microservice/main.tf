resource "kubernetes_deployment" "techchallenge_checkout_microservice" {
  metadata {
    name = "techchallenge-checkout-microservice"
    labels = {
      app = "techchallenge-checkout-microservice"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "techchallenge-checkout-microservice"
      }
    }

    template {
      metadata {
        labels = {
          app = "techchallenge-checkout-microservice"
        }
      }

      spec {
        automount_service_account_token = false

        container {
          name  = "techchallenge-k8s"
          image = "viniciusdeliz/techchallenge-checkout-microservice:main"

          port {
            container_port = 3002
          }

          env {
            name  = "MONGO_URI"
            value = "${var.mongo_uri}"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "techchallenge_checkout_microservice" {
  metadata {
    name = "techchallenge-checkout-microservice"
    labels = {
      app = "techchallenge-checkout-microservice"
    }
  }

  spec {
    selector = {
      app = "techchallenge-checkout-microservice"
    }

    port {
      protocol    = "TCP"
      port        = 3002
      target_port = 3002
    }

    type = "ClusterIP"
  }
}