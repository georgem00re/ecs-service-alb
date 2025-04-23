
locals {
  security_group_rule = object({
    cidr_ipv4 = string
    from_port = number
    ip_protocol = string
    to_port = number
  })
}

variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "inbound_rules" {
  type = list(local.security_group_rule)
}

variable "outbound_rules" {
  type = list(local.security_group_rule)
}
