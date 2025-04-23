
variable "min_capacity" {
  type = number
}

variable "max_capacity" {
  type = number
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "target_tracking_scaling_policies" {
  type = list(object({
    metric_type  = string
    target_value = number
  }))
}
