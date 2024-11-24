# Create Storage Class
resource "kubernetes_storage_class" "premium" {
  metadata {
    name = "terraform-example"
  }
  storage_provisioner = "kubernetes.io/azure-disk"
  reclaim_policy     = "Retain"
  parameters = {
    storageaccounttype = "Standard_LRS"
    kind               = "Managed"
  }
}

resource "azurerm_role_assignment" "aks_disk_contributor" {
  scope                = azurerm_managed_disk.postgres_disk.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.example.identity[0].principal_id
}

resource "kubernetes_persistent_volume" "postgres_pv" {
  metadata {
    name = "postgres-pv"
  }
  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      azure_disk {
        disk_name     = azurerm_managed_disk.postgres_disk.name
        data_disk_uri = azurerm_managed_disk.postgres_disk.id
        caching_mode  = "None"
        kind = "Managed"
      }
    }
    storage_class_name = kubernetes_storage_class.premium.metadata[0].name
    persistent_volume_reclaim_policy = "Retain"
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  metadata {
    name      = "postgres-pvc"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    storage_class_name = kubernetes_storage_class.premium.metadata[0].name
    volume_name        = kubernetes_persistent_volume.postgres_pv.metadata[0].name
  }
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    labels = {
      app = "postgres"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }
    strategy {
      type = "Recreate"
    }
    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }
      spec {
        container {
          name  = "postgres"
          image = "postgres:14"
          port {
            container_port = 5432
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }
          env {
            name  = "POSTGRES_USER"
            value = "docker"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "docker"
          }
          env {
            name  = "POSTGRES_DB"
            value = "techchallenge"
          }
          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
          volume_mount {
            mount_path = "/var/lib/postgresql/data"
            name       = "postgres-storage"
            sub_path   = "pgdata"
          }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
  }
  spec {
    selector = {
      app = "postgres"
    }
    port {
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}

resource "azurerm_managed_disk" "postgres_disk" {
  name                 = "postgres-disk"
  create_option        = "Empty"
  location             = azurerm_resource_group.example.location
  resource_group_name  = azurerm_resource_group.example.name
  storage_account_type = "Standard_LRS"
  disk_size_gb         = 1
  public_network_access_enabled = false
  tags = {
    environment = azurerm_resource_group.example.name
  }
}