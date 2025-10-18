# Project variable:
variable "project_id" {
  type        = string
  description = "Your GCP project id"
}

variable "region" {
  type        = string
  description = "Region to deploy resources on"
  default     = "europe-west1"
}

# Sink variable:
variable "log_filter_string" {
  type        = string
  description = "Your GA4 property id"
}

# Cloud Run Function env variables for Dataform run:
variable "env_var_2" {
  type        = string
  description = "Dataform region"
  sensitive   = false
}

variable "env_var_3" {
  type        = string
  description = "Dataform repo name"
  sensitive   = false
}

variable "env_var_4" {
  type        = string
  description = "Dataform workspace name"
  sensitive   = false
}
