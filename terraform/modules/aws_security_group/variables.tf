
variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "inbound_rules" {
  type = list(object({
    cidr_ipv4   = string
    from_port   = number
    ip_protocol = string
    to_port     = number
  }))
}

variable "outbound_rules" {
  type = list(object({
    cidr_ipv4   = string
    from_port   = number
    ip_protocol = string
    to_port     = number
  }))
}
