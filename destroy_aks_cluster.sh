#!/bin/bash

# Variables
RESOURCE_GROUP_NAME="ryad-k8s-wordpress"
CLUSTER_NAME="ryadK8sWordpressCluster"

# Suppression du cluster AKS
echo "Suppression du cluster AKS : $CLUSTER_NAME"
az aks delete \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $CLUSTER_NAME \
  --yes --no-wait

# Suppression du groupe de ressources
echo "Suppression du groupe de ressources : $RESOURCE_GROUP_NAME"
az group delete \
  --name $RESOURCE_GROUP_NAME \
  --yes --no-wait

echo "L'infrastructure a été supprimée avec succès."