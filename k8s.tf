provider "kubernetes" {
  host = aws_eks_cluster.av.endpoint
}

module "nginx-ingress-controller" {
  source  = "byuoitav/nginx-ingress-controller/kubernetes"
  version = "0.1.2"
}
