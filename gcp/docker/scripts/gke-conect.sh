#!/usr/bin/env bash
# connect to a gke cluster 
# assumes already connected to GCP via gcloud auth login
# Tom Daly : April 2024

# set project 
gcloud config set project mojaloop-vnext

# connect to cluster 
gcloud container clusters get-credentials cluster-1 --zone europe-west2-a --project mojaloop-vnext

# kubectl get nodes 
kubectl get nodes 