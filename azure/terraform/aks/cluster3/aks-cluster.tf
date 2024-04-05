# resource "random_pet" "prefix" {
#   length=3
# }

resource "azurerm_resource_group" "default" {
  #name     = "${random_pet.prefix.id}-rg"
  name = var.resource_group
  location = var.location

  tags = {
    environment = var.environment_tag 
  }
}

resource "azurerm_kubernetes_cluster" "default" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.k8s_version

  default_node_pool {
    name            = var.node_pool1
    #node_count      = 1
    vm_size         = var.shape
    enable_auto_scaling = true
    max_count           = var.max_node_count
    min_count           = var.min_node_count
    os_disk_size_gb = 100
  }

  service_principal {
    client_id     = var.appId
    client_secret = var.password
  }

  # role_based_access_control {
  #   enabled = true
  # }

  tags = {
    environment = var.environment_tag
    project = "mifos-auto"
  }
}
