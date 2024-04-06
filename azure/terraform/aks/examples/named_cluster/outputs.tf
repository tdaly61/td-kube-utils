output "test_aks_named_id" {
  value = module.aks.aks_id
}

output "test_aks_named_identity" {
  sensitive = true
  value     = try(module.aks.cluster_identity, "")
}
