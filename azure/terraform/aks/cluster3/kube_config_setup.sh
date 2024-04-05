#!/usr/bin/env bash
# configure kubectl 

CREDS_FILE=$HOME/my_creds.txt
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw kubernetes_cluster_name) > $CREDS_FILE 
