provider "aws" {
  region = "us-west-2"
}

// import information from byu acs
module "acs" {
  source            = "github.com/byuoitav/terraform//acs-info"
  env               = "prd"
  vpc_vpn_to_campus = true
}
