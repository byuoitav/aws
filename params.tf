resource "aws_ssm_parameter" "eks_av_cluster_endpoint" {
  name      = "/eks/av-cluster-endpoint"
  type      = "String"
  value     = aws_eks_cluster.av.endpoint
  overwrite = true
}

resource "aws_ssm_parameter" "eks_av_cluster_name" {
  name      = "/eks/av-cluster-name"
  type      = "String"
  value     = aws_eks_cluster.av.name
  overwrite = true
}

resource "aws_ssm_parameter" "acm_av_cert_arn" {
  name      = "/acm/av-cert-arn"
  type      = "String"
  value     = aws_acm_certificate.av_cert.arn
  overwrite = true
}

resource "aws_ssm_parameter" "route53_zone_av" {
  name      = "/route53/zone/av-id"
  type      = "String"
  value     = aws_route53_zone.av_zone.id
  overwrite = true
}

resource "aws_ssm_parameter" "eks_lb_name" {
  name      = "/eks/lb-name"
  type      = "String"
  value     = split("-", module.nginx_ingress_controller.lb_address)[0]
  overwrite = true
}

resource "aws_ssm_parameter" "eks_lb_name_private" {
  name      = "/eks/lb-name-private"
  type      = "String"
  value     = split("-", length(kubernetes_service.lb_private.load_balancer_ingress[0].ip) > 0 ? kubernetes_service.lb_private.load_balancer_ingress[0].ip : kubernetes_service.lb_private.load_balancer_ingress[0].hostname)[0]
  overwrite = true
}
