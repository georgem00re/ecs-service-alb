
variable "name" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "subnets" {
  type = list(string)
}

variable "container_name" {
  type = string
}

variable "task_definition_name" {
  type = string
}

variable "desired_count" {
  type = number
}

variable "load_balancer_target_group_arn" {
  type = string
}

variable "host_port" {
  type = number
}

variable "container_port" {
  type = number
}

variable "memory" {
  type = number
}

variable "cpu" {
  type = number
}

variable "image_url" {
  type = string
}
