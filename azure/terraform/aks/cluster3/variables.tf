
variable "resource_group" {
  description = "Azure resource group "
  type        = string
}

variable "location" {
  description = "Azure location "
  type        = string
}

variable "environment_tag" {
  description = "tag value for environment "
  type        = string
}

variable "cluster_name" {
  type    = string
}

variable "k8s_version" {
  type = string
}

variable "dns_prefix" {
  type    = string
}

variable "node_pool1" {
  type    = string
  default = "k8scontrol"
}

variable "node_pool2" {
  type    = string
  default = "npool2"
}
variable "min_node_count" {
  type    = number
  default = 2
}

variable "max_node_count" {
  type    = number
  default = 6
}

variable "shape" {
  type    = string
  default = "Standard_D2_v2"
}

variable "appId" {
  description = "Azure Kubernetes Service Cluster service principal"
}

variable "password" {
  description = "Azure Kubernetes Service Cluster password"
}
