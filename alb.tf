// import information from byu acs
module "acs" {
  source = "git@github.com:byu-oit/terraform-aws-acs-info.git?ref=v1.2.0"
  env    = "prd"
}

// the production load balancer
resource "aws_lb" "prd_alb" {
  name               = "production alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["${module.acs.public_subnet_ids}"]
  security_groups    = ["${aws_security_group.prd_alb_sg.id}"]

  enable_deletion_protection = false // while i test :) 

  tags {
    env              = "prd"
    data-sensitivity = "internal"
    repo             = "https://github.com/byuoitav/aws"
  }
}

// redirect http -> https
resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_lb.prd_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_308" // 308 because we support multiple HTTP methods
    }
  }
}

// security group for production load balancer
resource "aws_security_group" "prd_alb_sg" {
  name   = "production alb security group"
  vpc_id = "${module.acs.vpc_id}"

  tags {
    env              = "prd"
    data-sensitivity = "internal"
    repo             = "https://github.com/byuoitav/aws"
  }
}

resource "aws_security_group_rule" "http_from_anywhere" {
  security_group_id = "${aws_security_group.prd_alb_sg.id}"

  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https_from_anywhere" {
  security_group_id = "${aws_security_group.prd_alb_sg.id}"

  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "outbound_internet_access" {
  security_group_id = "${aws_security_group.prd_alb_sg.id}"

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1" // allow all protocols for outbound traffic
  cidr_blocks = ["0.0.0.0/0"]
}