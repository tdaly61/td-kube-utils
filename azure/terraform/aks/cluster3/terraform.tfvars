
resource_group = "td-mifos-auto"
location = "eastus"
environment_tag = "td_auto"
cluster_name = "mifos_auto1"
k8s_version = "1.28.5"
dns_prefix = "mifosauto1"
shape = "Standard_A4_v2"


appId    = ""
password = ""

#nonroot@607302cda10d:/terraform/aks/first-cluster$ az ad sp create-for-rbac --skip-assignment
# Option '--skip-assignment' has been deprecated and will be removed in a future release.
# The output includes credentials that you must protect. Be sure that you do not include these credentials in your code or check the credentials into your source control. For more information, see https://aka.ms/azadsp-cli
# {
#   "appId": "746b03e6-d09c-4750-af27-73b003aaee7f",
#   "displayName": "azure-cli-2022-12-17-06-33-46",
#   "password": "Q_Fqajr0mkQz2BMRKua6rqFR~1wlT7IY1q",
#   "tenant": "1a403cb4-e146-4a95-9639-32916f97f2ef"
#}
