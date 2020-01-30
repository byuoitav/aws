module "alb-ingress-controller" {
  source  = "iplabs/alb-ingress-controller/kubernetes"
  version = "2.0.0"

  aws_iam_path_prefix = "/eks/av/"
  aws_region_name     = "us-west-2"
  aws_vpc_id          = module.acs.vpc.id
  k8s_cluster_name    = aws_eks_cluster.av.name
}

resource "aws_iam_policy" "ALBIngressControllerPolicy" {
  name        = "eks-node-group-alb-ingress-controller"
  path        = "/"
  description = "Allow aws alb ingress controller to get HTTPS certs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:ListServerCertificates",
          "acm:ListCertificates"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_group-ListServerCertificatesPolicy" {
  policy_arn = aws_iam_policy.ALBIngressControllerPolicy.arn
  role       = aws_iam_role.eks_node_group.name
}

// external dns through r53
resource "kubernetes_service_account" "external_dns" {
  metadata {
    name = "external-dns"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eks_node_group.arn
    }
  }
}

resource "kubernetes_cluster_role" "external_dns" {
  metadata {
    name = "external-dns"
  }

  rule {
    api_groups = [""]
    resources  = ["services"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["list"]
  }
}

resource "kubernetes_cluster_role_binding" "external_dns" {
  metadata {
    name = "external-dns-viewer"
  }

  role_ref {
    kind      = "ClusterRole"
    api_group = "rbac.authorization.k8s.io"
    name      = kubernetes_cluster_role.external_dns.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_cluster_role.external_dns.metadata.0.name
    namespace = "default"
  }
}

resource "kubernetes_deployment" "external_dns" {
  metadata {
    name = "external-dns"
  }

  spec {
    selector {
      match_labels = {
        app = "external-dns"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "external-dns"
        }

        annotations = {
          "iam.amazonaws.com/role" = aws_iam_role.eks_node_group.arn
        }
      }

      spec {
        service_account_name = kubernetes_service_account.external_dns.metadata.0.name

        container {
          name              = "external-dns"
          image             = "registry.opensource.zalan.do/teapot/external-dns:latest"
          image_pull_policy = "Always"

          args = [
            "--source=service",
            "--source=ingress",
            "--domain-filter=av.byu.edu", // can't use av_zone because it has the . at the end
            "--provider=aws",
            "--aws-zone-type=public",
            "--registry=txt",
            "--txt-owner-id=av-k8s-cluster"
          ]

          volume_mount {
            mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
            name       = kubernetes_service_account.external_dns.default_secret_name
            read_only  = true
          }
        }

        volume {
          name = kubernetes_service_account.external_dns.default_secret_name

          secret {
            secret_name = kubernetes_service_account.external_dns.default_secret_name
          }
        }

        // needed to be able to read the token
        security_context {
          fs_group = 65534
        }
      }
    }
  }

  timeouts {
    create = "3m"
    update = "3m"
  }
}
