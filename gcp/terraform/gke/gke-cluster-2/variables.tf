
variable "project_id" {
  description = "GCP project id  "
  type        = string
}

variable "region" {
  description = "GCP region "
  type        = string
}

variable "zones_list" {
  description = "list of zones for cluster"
  type    = list(string)
}

variable "cluster_name" {
  type    = string
}

variable "network_name" {
  type    = string
}

variable "subnetwork" {
  type    = string
}

variable "ip_range_pods" {
  type    = string
}

variable "ip_range_services" {
  type    = string
}

variable "node_locations" {
  type    = string
}



# variable "service_account" {
#   type    = string
# }