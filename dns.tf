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
  name    = aws_acm_certificate.av_cert.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.av_cert.domain_validation_options.0.resource_record_type
  zone_id = aws_route53_zone.av_zone.id
  records = [aws_acm_certificate.av_cert.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "av_cert" {
  certificate_arn         = aws_acm_certificate.av_cert.arn
  validation_record_fqdns = [aws_route53_record.av_cert_validation.fqdn]
}
