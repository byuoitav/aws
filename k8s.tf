provider "kubernetes" {
  host = aws_eks_cluster.av.endpoint

  client_certificate = aws_eks_cluster.av.certificate_authority.0.data
}
