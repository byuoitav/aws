// ebs blocks
resource "aws_ebs_volume" "couchdb_ebs_0" {
  availability_zone = "us-west-2b"
  size              = 40
  encrypted         = true
}

resource "aws_ebs_volume" "couchdb_ebs_1" {
  availability_zone = "us-west-2b"
  size              = 40
  encrypted         = true
}

resource "aws_ebs_volume" "couchdb_ebs_2" {
  availability_zone = "us-west-2b"
  size              = 40
  encrypted         = true
}

// k8s persistant volumes
resource "kubernetes_persistent_volume" "couchdb_pv_0" {
  metadata {
    name = "couch-pv-0"
    labels = {
      volume = "couch-pv"
    }
  }

  spec {
    capacity = {
      storage = "40Gi"
    }

    access_modes = ["ReadWriteOnce"]

    persistent_volume_source {
      aws_elastic_block_store {
        volume_id = aws_ebs_volume.couchdb_ebs_0.id
        fs_type   = "ext4"
      }
    }
  }
}

resource "kubernetes_persistent_volume" "couchdb_pv_1" {
  metadata {
    name = "couch-pv-1"
    labels = {
      volume = "couch-pv"
    }
  }

  spec {
    capacity = {
      storage = "40Gi"
    }

    access_modes = ["ReadWriteOnce"]

    persistent_volume_source {
      aws_elastic_block_store {
        volume_id = aws_ebs_volume.couchdb_ebs_1.id
        fs_type   = "ext4"
      }
    }
  }
}

resource "kubernetes_persistent_volume" "couchdb_pv_2" {
  metadata {
    name = "couch-pv-2"
    labels = {
      volume = "couch-pv"
    }
  }

  spec {
    capacity = {
      storage = "40Gi"
    }

    access_modes = ["ReadWriteOnce"]

    persistent_volume_source {
      aws_elastic_block_store {
        volume_id = aws_ebs_volume.couchdb_ebs_2.id
        fs_type   = "ext4"
      }
    }
  }
}

// k8s stateful set
resource "kubernetes_stateful_set" "couchdb" {
  metadata {
    name = "couchdb"

    annotations = {}
  }

  spec {
    service_name = "couch-service"
    replicas     = 3

    selector {
      match_labels = {
        app = "couchdb"
      }
    }

    template {
      metadata {
        labels = {
          app = "couchdb" // pod label
        }

        annotations = {}
      }

      spec {
        container {
          name              = "couchdb"
          image             = "couchdb:2.3.1"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "couchdb"
            container_port = 5984
          }

          port {
            name           = "epmd"
            container_port = 4369
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

          resources {
            limits {
              cpu    = "1"
              memory = "1Gi"
            }

            requests {
              cpu    = ".5"
              memory = "500Mi"
            }
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "storage"

        labels = {
          app = "couchdb"
        }
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        selector {
          match_labels = {
            volume = "couch-pv"
          }
        }

        resources {
          requests = {
            storage = "40Gi"
          }
        }
      }
    }
  }
}
