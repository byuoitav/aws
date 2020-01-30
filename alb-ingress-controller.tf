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
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_group-ListServerCertificatesPolicy" {
  policy_arn = aws_iam_policy.ALBIngressControllerPolicy.arn
  role       = aws_iam_role.eks_node_group.name
}
