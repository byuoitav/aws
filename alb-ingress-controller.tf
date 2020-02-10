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

/*
resource "kubernetes_deployment" "external_dns" {
  spec {
    strategy {
      type = "Recreate"
    }
  }
}
*/
