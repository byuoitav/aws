provider "kubernetes" {
  host = aws_eks_cluster.av.endpoint
}

module "nginx_ingress_controller" {
  source  = "byuoitav/nginx-ingress-controller/kubernetes"
  version = "0.1.8"
}
