
variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "inbound_rules" {
  type = list(object({
    rule_number   = number
    protocol      = string
    allow_or_deny = string
    cidr_block    = string
    from_port     = number
    to_port       = number
  }))
}

variable "outbound_rules" {
  type = list(object({
    rule_number   = number
    protocol      = string
    allow_or_deny = string
    cidr_block    = string
    from_port     = number
    to_port       = number
  }))
}
