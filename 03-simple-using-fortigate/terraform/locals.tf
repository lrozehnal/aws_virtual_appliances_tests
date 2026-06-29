locals {
  aws_config_env = yamldecode(file("../config/config.yaml"))
  domain         = "mplexia.com"
  fortinetpassword = "AdminAdmin12!"
  tags = {
    terraform = "yes"
    github    = "https://github.com/lrozehnal/aws_virtual_appliances_tests"
  }
}

