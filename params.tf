resource "aws_ssm_parameter" "eks_av_cluster_endpoint" {
  name      = "/eks/av-cluster-endpoint"
  type      = "String"
  value     = aws_eks_cluster.av.endpoint
  overwrite = true
}

resource "aws_ssm_parameter" "acm_av_cert_arn" {
  name      = "/acm/av-cert-arn"
  type      = "String"
  value     = aws_acm_certificate.av_cert.arn
  overwrite = true
}
