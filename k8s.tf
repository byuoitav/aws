provider "kubernetes" {
  host = aws_eks_cluster.av.endpoint
}

module "nginx_ingress_controller" {
  source              = "byuoitav/nginx-ingress-controller/kubernetes"
  version             = "0.1.14"
  controller_replicas = 3
  lb_annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
    "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
  }
  nginx_config = {
    "ssl-protocols" = "TLSv1 TLSv1.1 TLSv1.2"
    "ssl-ciphers"   = "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA"
  }
}

resource "kubernetes_service" "lb_private" {
  metadata {
    name      = "ingress-nginx-private"
    namespace = "ingress-nginx"

    labels = {
      "app.kubernetes.io/name"       = "ingress-nginx-private"
      "app.kubernetes.io/part-of"    = "ingress-nginx"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-internal"                          = "true"
      "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
    }
  }

  spec {
    type = "LoadBalancer"
    selector = {
      "app.kubernetes.io/name"    = "ingress-nginx"
      "app.kubernetes.io/part-of" = "ingress-nginx"
    }

    external_traffic_policy = "Local"

    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }

    port {
      name        = "https"
      port        = 443
      target_port = "https"
    }
  }
}
