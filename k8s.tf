provider "kubernetes" {
  host = aws_eks_cluster.av.endpoint

  client_certificate = aws_eks_cluster.av.certificate_authority.0.data
}

module "alb-ingress-controller" {
  source  = "byuoitav/alb-ingress-controller/kubernetes"
  version = "1.0.0"

  // required
  k8s_cluster_name = aws_eks_cluster.av.name

  // optional
  aws_tags = {
    // TODO
  }
}
