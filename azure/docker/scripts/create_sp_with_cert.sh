#!/usr/bin/env bash
# create a service principal with cert authentication 
SPNAME=tomsp
ROLENAME="USER"
SUBSCRIPTION_ID="" # Azure subscription 1
# to get subscription_id run az account show --query id -o tsv 
CERTPATH=/ssh/azure.pem
RG="td_rg1"

#use this one if you have a cert already 
# az ad sp create-for-rbac --name $SPNAME \
#                          --role $ROLENAME \
#                          --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG \
#                          --cert @/path/to/cert.pem

#use this one to create a cert 
az ad sp create-for-rbac --name $SPNAME \
                         --role $ROLENAME \
                         --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG \
                         --create-cert

# az ad sp create-for-rbac --name myServicePrincipalName \
#                          --role roleName \
#                          --scopes /subscriptions/mySubscriptionID/resourceGroups/myResourceGroupName \
#                          --cert "-----BEGIN CERTIFICATE-----
# ...
# -----END CERTIFICATE-----"