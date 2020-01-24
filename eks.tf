// iam junk for eks cluster
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"
  // permissions_boundary = "arn:aws:iam::586877430255:policy/iamRolePermissionBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

// eks cluster
resource "aws_eks_cluster" "eks" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = module.acs.private_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster-AmazonEKSServicePolicy,
  ]
}

// iam junk for eks nodes
resource "aws_iam_role" "eks_node_group" {
  name = "eks-node-group-role"
  // permissions_boundary = "arn:aws:iam::586877430255:policy/iamRolePermissionBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_group-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_node_group-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_node_group-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = module.acs.private_subnet_ids

  ami_type       = "AL2_x86_64"
  disk_size      = "10"
  instance_types = ["t3.large"]

  scaling_config {
    desired_size = 4
    max_size     = 6
    min_size     = 4
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_group-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_node_group-AmazonEC2ContainerRegistryReadOnly,
  ]
}

locals {
  alb_ctl_name = "alb-ingress-controller"
}

// cluster role for alb ingress controller (from https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.5/docs/examples/rbac-role.yaml)
resource "kubernetes_cluster_role" "alb_ingress_controller" {
  metadata {
    name = local.alb_ctl_name
    labels = {
      "app.kubernetes.io/name" = local.alb_ctl_name
    }
  }

  rule {
    api_groups = ["", "extensions"]
    resources  = ["configmaps", "endpoints", "events", "ingresses", "ingresses/status", "services"]
    verbs      = ["create", "get", "list", "update", "watch", "patch"]
  }

  rule {
    api_groups = ["", "extensions"]
    resources  = ["nodes", "pods", "secrets", "services", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "alb_ingress_controller" {
  metadata {
    name = local.alb_ctl_name
    labels = {
      "app.kubernetes.io/name" = local.alb_ctl_name
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.alb_ingress_controller.metadata.0.name
  }

  subject {
    name      = local.alb_ctl_name
    kind      = "ServiceAccount"
    namespace = "kube-system"
  }
}

resource "kubernetes_service_account" "alb_ingress_controller" {
  metadata {
    name      = local.alb_ctl_name
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = local.alb_ctl_name
    }
  }
}

// aws alb ingress controller deployment (from https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.5/docs/examples/alb-ingress-controller.yaml)
resource "kubernetes_deployment" "alb_ingress_controller" {
  metadata {
    name      = local.alb_ctl_name
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = local.alb_ctl_name
    }
  }

  spec {
    selector {
      match_labels = {
        "app.kubernetes.io/name" = local.alb_ctl_name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = local.alb_ctl_name
        }
      }

      spec {
        container {
          name  = local.alb_ctl_name
          image = "docker.io/amazon/aws-alb-ingress-controller:v1.1.5"

          args = ["--cluster-name=${aws_eks_cluster.eks.name}"]

          env {
            name  = "AWS_ACCESS_KEY_ID"
            value = "" // TODO IAM user
          }

          env {
            name  = "AWS_SECRET_ACCESS_KEY"
            value = ""
          }
        }

        service_account_name = local.alb_ctl_name
      }
    }
  }
}
