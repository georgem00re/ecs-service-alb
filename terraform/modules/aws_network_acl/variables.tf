
locals {
  nacl_rule = object({
    rule_number   = number
    protocol      = string
    allow_or_deny = string
    cidr_block    = string
    from_port     = number
    to_port       = number
  })
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = set(string)
}

variable "inbound_rules" {
  type = list(local.nacl_rule)
}

variable "outbound_rules" {
  type = list(local.nacl_rule)
}
