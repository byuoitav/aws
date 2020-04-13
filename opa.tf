// ----------------------------------------------------
// Data
// ----------------------------------------------------
data "aws_ssm_parameter" "acm_cert_arn" {
  name = "/acm/av-cert-arn"
}

data "aws_ssm_parameter" "r53_zone_id" {
  name = "/route53/zone/av-id"
}

data "aws_ssm_parameter" "eks_lb_name" {
  name = "/eks/lb-name"
}

data "aws_ssm_parameter" "eks_cluster_name" {
  name = "/eks/av-cluster-name"
}

data "aws_ssm_parameter" "role_boundary" {
  name = "/acs/iam/iamRolePermissionBoundary"
}

data "aws_ssm_parameter" "root_bearer_token" {
  name = "/opa/root-bearer-token"
}

data "aws_lb" "eks_lb" {
  name = data.aws_ssm_parameter.eks_lb_name.value
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "selected" {
  name = data.aws_ssm_parameter.eks_cluster_name.value
}

data "aws_iam_policy_document" "eks_oidc_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.selected.identity.0.oidc.0.issuer, "https://", "")}:sub"
      values = [
        "system:serviceaccount:default:${local.name}",
      ]
    }

    principals {
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.selected.identity.0.oidc.0.issuer, "https://", "")}"
      ]
      type = "Federated"
    }
  }
}

// ----------------------------------------------------
// Variables
// ----------------------------------------------------
locals {
  name                 = "opa-dev"
  image                = "openpolicyagent/opa"
  image_version        = "latest"
  container_port       = 8181
  repo_url             = "https://github.com/byuoitav/aws"
  storage_mount_path   = "/opt/policies"
  storage_request_size = "10Gi"
  image_pull_secret    = ""
  ingress_annotations  = {}
  public_urls          = ["opa.av.byu.edu"]
  iam_policy_doc       = <<EOT
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Action":[
            "s3:ListAllMyBuckets"
         ],
         "Resource":"arn:aws:s3:::*"
      },
      {
         "Effect":"Allow",
         "Action":[
            "s3:ListBucket",
            "s3:GetBucketLocation"
         ],
         "Resource":"arn:aws:s3:::${aws_s3_bucket.opa_bucket.id}"
      },
      {
         "Effect":"Allow",
         "Action":[
            "s3:GetObject",
            "s3:GetObjectAcl"
         ],
         "Resource":"arn:aws:s3:::${aws_s3_bucket.opa_bucket.id}/*"
      }
   ]
}
EOT

  container_env = {
    AWS_REGION            = "us-west-2"
    IAM_ROLE              = aws_iam_role.eks_node_group.name
    OPA_POLICY_BUCKET_URL = "https://${aws_s3_bucket.opa_bucket.id}.s3.amazonaws.com"
    BUNDLE_PATH           = "/av_bundle.tar.gz"
    ROOT_BEARER_TOKEN     = data.aws_ssm_parameter.root_bearer_token.value
  }
  container_args = [
    "run", "--server",
    "--log-level", "debug",
    "--config-file", "/policies/config.yaml",
    "--authentication=token",
    "--authorization=basic"
  ]
}

// ----------------------------------------------------
// Setup bucket for policies
// ----------------------------------------------------
resource "aws_s3_bucket" "opa_bucket" {
  bucket = "byuoitav-opa-policies"
  acl    = "private"
  tags = {
    env              = "prd"
    data-sensitivity = "confidential"
    team             = "AV Engineering"
  }
}

resource "aws_ssm_parameter" "opa_bucket" {
  name  = "/opa/policy-bucket-name"
  type  = "String"
  value = aws_s3_bucket.opa_bucket.id
}

// ----------------------------------------------------
// IAM Role
// ----------------------------------------------------
resource "aws_iam_role" "this" {
  name = "eks-${data.aws_ssm_parameter.eks_cluster_name.value}-${local.name}"

  assume_role_policy   = data.aws_iam_policy_document.eks_oidc_assume_role.json
  permissions_boundary = data.aws_ssm_parameter.role_boundary.value

  tags = {
    env  = "prd"
    repo = local.repo_url
  }

}

resource "aws_iam_policy" "this" {
  name   = "eks-${data.aws_ssm_parameter.eks_cluster_name.value}-${local.name}"
  policy = local.iam_policy_doc
}

resource "aws_iam_policy_attachment" "this" {
  name       = "eks-${data.aws_ssm_parameter.eks_cluster_name.value}-${local.name}"
  policy_arn = aws_iam_policy.this.arn
  roles      = [aws_iam_role.this.name]
}

// ----------------------------------------------------
// K8s Deployment, Service, Ingress
// ----------------------------------------------------
resource "kubernetes_service_account" "this" {
  metadata {
    name = local.name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }

    labels = {
      "app.kubernetes.io/name"       = local.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_deployment" "this" {
  metadata {
    name = local.name

    labels = {
      "app.kubernetes.io/name"       = local.name
      "app.kubernetes.io/version"    = local.image_version
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = local.name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = local.name
          "app.kubernetes.io/version" = local.image_version
        }
      }

      spec {
        service_account_name = kubernetes_service_account.this.metadata.0.name

        dynamic "image_pull_secrets" {
          for_each = length(local.image_pull_secret) > 0 ? [local.image_pull_secret] : []

          content {
            name = image_pull_secrets.value
          }
        }

        volume {
          name = "opa-policies"
          empty_dir {
            medium = ""
          }
        }

        init_container {
          name  = "initialize-config"
          image = "amazon/aws-cli:latest"
          command = [
            "/usr/local/bin/aws",
            "s3",
            "cp",
            "s3://${aws_s3_bucket.opa_bucket.id}/config.yaml",
            "/policies/config.yaml"
          ]

          volume_mount {
            mount_path = "/policies"
            name       = "opa-policies"
          }

          volume_mount {
            mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
            name       = kubernetes_service_account.this.default_secret_name
            read_only  = true
          }

        }

        container {
          name              = "server"
          image             = "${local.image}:${local.image_version}"
          image_pull_policy = "Always"

          args = local.container_args

          port {
            container_port = local.container_port
          }

          // environment vars
          dynamic "env" {
            for_each = local.container_env

            content {
              name  = env.key
              value = env.value
            }
          }

          // Volume mounts
          volume_mount {
            mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
            name       = kubernetes_service_account.this.default_secret_name
            read_only  = true
          }

          volume_mount {
            mount_path = "/policies"
            name       = "opa-policies"
          }

          // container is killed it if fails this check
          liveness_probe {
            http_get {
              port = local.container_port
              path = "/health"
            }

            initial_delay_seconds = 60
            period_seconds        = 60
            timeout_seconds       = 3
          }

          // container is isolated from new traffic if fails this check
          readiness_probe {
            http_get {
              port = local.container_port
              path = "/health"
            }

            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 3
          }
        }

        volume {
          name = kubernetes_service_account.this.default_secret_name

          secret {
            secret_name = kubernetes_service_account.this.default_secret_name
          }
        }
      }
    }
  }

  timeouts {
    create = "5m"
    update = "5m"
    delete = "10m"
  }
}

// let everyone get to this service at one IP
resource "kubernetes_service" "this" {
  metadata {
    name = local.name

    labels = {
      "app.kubernetes.io/name"       = local.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    type = "ClusterIP"
    port {
      port        = 80
      target_port = local.container_port
    }

    selector = {
      "app.kubernetes.io/name" = local.name
    }
  }
}

// create the route53 entry
resource "aws_route53_record" "this" {
  count = length(local.public_urls)

  zone_id = data.aws_ssm_parameter.r53_zone_id.value
  name    = local.public_urls[count.index]
  type    = "A"

  alias {
    name                   = data.aws_lb.eks_lb.dns_name
    zone_id                = data.aws_lb.eks_lb.zone_id
    evaluate_target_health = false
  }
}

resource "kubernetes_ingress" "this" {
  // only create the ingress if there is at least one public url
  count = length(local.public_urls) > 0 ? 1 : 0

  metadata {
    name = local.name

    labels = {
      "app.kubernetes.io/name"       = local.name
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = merge(local.ingress_annotations, {
      "kubernetes.io/ingress.class"                    = "nginx"
      "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
    })
  }

  spec {
    tls {
      secret_name = "star-av-byu-edu"
      hosts       = local.public_urls
    }

    dynamic "rule" {
      for_each = local.public_urls

      content {
        host = rule.value

        http {
          path {
            backend {
              service_name = kubernetes_service.this.metadata.0.name
              service_port = 80
            }
          }
        }
      }
    }
  }
}
