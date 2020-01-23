// k8s storage class for aws
resource "kubernetes_storage_class" "ebs_couch" {
  metadata {
    name = "ebs-couch"
  }

  storage_provisioner    = "kubernetes.io/aws-ebs"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true

  parameters = {
    type      = "gp2"
    fsType    = "ext4"
    encrypted = "true"
  }
}

// k8s stateful set for couch
resource "kubernetes_stateful_set" "couchdb" {
  metadata {
    name = "couchdb"

    labels = {
      app = "couchdb"
    }
  }

  spec {
    service_name = "couchdb"
    replicas     = 3

    selector {
      match_labels = {
        app = "couchdb"
      }
    }

    template {
      metadata {
        labels = {
          app = "couchdb"
        }
      }

      spec {
        container {
          name              = "couchdb"
          image             = "couchdb:2.3.1"
          image_pull_policy = "Always"

          port {
            name           = "couchdb"
            container_port = 5984
          }

          port {
            name           = "epmd"
            container_port = 4369
          }

          port {
            // what is this lol
            container_port = 9100
          }

          resources {
            requests {
              cpu    = "500m"
              memory = "500Mi"
            }
            limits {
              cpu    = "1"
              memory = "1Gi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 5984
            }
          }

          readiness_probe {
            http_get {
              path = "/_up"
              port = 5984
            }
          }

          volume_mount {
            name       = "config-storage"
            mount_path = "/opt/couchdb/etc/default.d"
          }

          volume_mount {
            name       = "database-storage"
            mount_path = "/opt/couchdb/data"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "config-storage"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = kubernetes_storage_class.ebs_couch.metadata.0.name

        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "database-storage"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = kubernetes_storage_class.ebs_couch.metadata.0.name

        resources {
          requests = {
            storage = "30Gi"
          }
        }
      }
    }
  }
}
