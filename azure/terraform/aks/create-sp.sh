#!/usr/bin/env bash
# see https://learn.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli

az ad sp create-for-rbac --name  \
                         --role roleName \
                         --scopes /subscriptions/mySubscriptionID/resourceGroups/myResourceGroupName \
                         --create-cert