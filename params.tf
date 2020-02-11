resource "aws_ssm_parameter" "eks_cluster_name" {
  name  = "/eks/default-cluster-name"
  type  = "String"
  value = aws_eks_cluster.av.name
}

resource "aws_ssm_parameter" "acm_cert_arn" {
  name  = "/acm/av-cert-arn"
  type  = "String"
  value = aws_acm_certificate.av_cert.arn
}
