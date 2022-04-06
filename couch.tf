locals {
  couch_name = "couchdb"
}

resource "aws_route53_record" "couch" {
  zone_id = data.aws_ssm_parameter.r53_zone_id.value
  name    = "couch.av.byu.edu"
  type    = "A"

  alias {
    name                   = data.aws_lb.eks_lb.dns_name
    zone_id                = data.aws_lb.eks_lb.zone_id
    evaluate_target_health = false
  }
}


