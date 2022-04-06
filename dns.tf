resource "aws_route53_zone" "av_zone" {
  name = "av.byu.edu."

  tags = {
    env              = "prd"
    data-sensitivity = "internal"
    repo             = "https://github.com/byuoitav/aws"
  }
}

resource "aws_acm_certificate" "av_cert" {
  domain_name       = "*.av.byu.edu"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    env              = "prd"
    data-sensitivity = "internal"
    repo             = "https://github.com/byuoitav/aws"
  }
}

resource "aws_route53_record" "av_cert_validation" {
  name    = tolist(aws_acm_certificate.av_cert.domain_validation_options).0.resource_record_name
  type    = tolist(aws_acm_certificate.av_cert.domain_validation_options).0.resource_record_type
  zone_id = aws_route53_zone.av_zone.id
  records = [tolist(aws_acm_certificate.av_cert.domain_validation_options).0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "av_cert" {
  certificate_arn         = aws_acm_certificate.av_cert.arn
  validation_record_fqdns = [aws_route53_record.av_cert_validation.fqdn]
}

## avs.byu.edu ##

resource "aws_route53_zone" "avs_zone" {
  name = "avs.byu.edu."

  tags = {
    env              = "prd"
    data-sensitivity = "internal"
    repo             = "https://github.com/byuoitav/aws"
  }
}

resource "aws_acm_certificate" "avs_cert" {
  domain_name       = "*.avs.byu.edu"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    env              = "prd"
    data-sensitivity = "internal"
    repo             = "https://github.com/byuoitav/aws"
  }
}

resource "aws_route53_record" "avs_cert_validation" {
  name    = tolist(aws_acm_certificate.avs_cert.domain_validation_options).0.resource_record_name
  type    = tolist(aws_acm_certificate.avs_cert.domain_validation_options).0.resource_record_type
  zone_id = aws_route53_zone.avs_zone.id
  records = [tolist(aws_acm_certificate.avs_cert.domain_validation_options).0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "avs_cert" {
  certificate_arn         = aws_acm_certificate.avs_cert.arn
  validation_record_fqdns = [aws_route53_record.avs_cert_validation.fqdn]
}

resource "aws_route53_record" "couchdb_prd_avs" {
  name    = "couchdb-prd.avs.byu.edu"
  type    = "A"
  ttl     = 600
  zone_id = aws_route53_zone.avs_zone.id
  records = [
    "44.235.99.60",
    "44.241.49.26"
  ]
}

