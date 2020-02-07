module "alb-ingress-controller" {
  source  = "byuoitav/alb-ingress-controller/kubernetes"
  version = "0.1.2"

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
