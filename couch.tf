locals {
  couch_name = "couchdb"
}

// k8s storage class for aws
resource "kubernetes_storage_class" "ebs_couch" {
  metadata {
    name = local.couch_name

    labels = {
      "app.kubernetes.io/name"       = local.couch_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
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
    name = local.couch_name

    labels = {
      "app.kubernetes.io/name"       = local.couch_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    service_name = local.couch_name
    replicas     = 3

    selector {
      match_labels = {
        "app.kubernetes.io/name" = local.couch_name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = local.couch_name
          "app.kubernetes.io/version" = "2.3.1"
        }
      }

      spec {
        container {
          name              = local.couch_name
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

          // TODO pick these
          // environment vars
          env {
            name  = "COUCHDB_USER"
            value = "admin"
          }

          env {
            name  = "COUCHDB_PASSWORD"
            value = "password"
          }

          // clustering env vars
          env {
            name  = "COUCHDB_SECRET"
            value = "topSecret"
          }

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name  = "NODENAME"
            value = "$(POD_NAME).service"
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

        labels = {
          "app.kubernetes.io/name"       = "config-storage"
          "app.kubernetes.io/managed-by" = "terraform"
        }
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

        labels = {
          "app.kubernetes.io/name"       = "database-storage"
          "app.kubernetes.io/managed-by" = "terraform"
        }
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

// create service for cluster-local access
resource "kubernetes_service" "couchdb_cluster_ip" {
  metadata {
    name = local.couch_name

    labels = {
      "app.kubernetes.io/name"       = local.couch_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    type = "ClusterIP"
    port {
      port        = 5984
      target_port = 5984
      protocol    = "TCP"
    }

    selector = {
      "app.kubernetes.io/name" = local.couch_name
    }
  }
}

// create ingress (loadbalancer)
resource "kubernetes_ingress" "couchdb" {
  metadata {
    name = local.couch_name

    labels = {
      "app.kubernetes.io/name"       = local.couch_name
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/subnets"         = join(",", module.acs.public_subnet_ids)
      "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.av_cert.arn
      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([
        { HTTP = 80 },
        { HTTPS = 443 }
      ])

      "alb.ingress.kubernetes.io/actions.ssl-redirect" = jsonencode({
        Type = "redirect"
        RedirectConfig = {
          Protocol   = "HTTPS"
          Port       = "443"
          StatusCode = "HTTP_301"
        }
      })

      "alb.ingress.kubernetes.io/tags" = "env=prd,data-sensitivity=internal,repo=https://github.com/byuoitav/aws"
    }
  }

  spec {
    rule {
      host = "db.av.byu.edu"

      http {
        // redirect to https
        path {
          backend {
            service_name = "ssl-redirect"
            service_port = "use-annotation"
          }
        }

        // forward to couchdb
        path {
          backend {
            service_name = local.couch_name
            service_port = 5984
          }
        }
      }
    }
  }
}
