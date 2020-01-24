// k8s storage class for aws
resource "kubernetes_storage_class" "ebs_couch" {
  metadata {
    name = "ebs-couch"
  }

  storage_provisioner    = "kubernetes.io/aws-ebs"
  reclaim_policy         = "Delete" // probably Retain
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
            // "discovery" port
            name           = "epmd"
            container_port = 4369
          }

          port {
            // for erlang communication
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

          // environment vars
          env {
            name  = "COUCHDB_USER"
            value = "admin"
          }

          env {
            name  = "COUCHDB_PASSWORD"
            value = "password"
          }

          env {
            name  = "COUCHDB_SECRET"
            value = "topSecret"
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
            mount_path = "/opt/couchdb/etc/local.d"
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
            storage = "256Mi"
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

// node port service
resource "kubernetes_service" "couchdb" {
  metadata {
    name = "couch-nodep"
  }

  spec {
    type = "NodePort"
    port {
      port        = 80
      target_port = 5984
    }

    selector = {
      app = "couch"
    }
  }
}

// load balancer for couch
resource "kubernetes_ingress" "couchdb" {
  metadata {
    name = "couchdb-ingress"

    annotations = {
      "kubernetes.io/ingress.class" = "alb"
    }
  }

  spec {
    rule {
      host = "couch.av.byu.edu"

      http {
        path {
          backend {
            service_name = "couchdb"
            service_port = "80"
          }
        }
      }
    }
  }
}
