#!/bin/bash

# Variables
RESOURCE_GROUP_NAME="Abdel_ressource"
CLUSTER_NAME="Abdel_cluster"
LOCATION="eastus"
NODE_COUNT=3

# Création du groupe de ressources
echo "Création du groupe de ressources : $RESOURCE_GROUP_NAME"
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

# Création du cluster AKS
echo "Création du cluster AKS : $CLUSTER_NAME"
az aks create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --enable-addons monitoring \
  --generate-ssh-keys \
  --location $LOCATION

# Affichage des informations de connexion
echo "Cluster AKS créé avec succès !"
echo "Connexion au cluster AKS..."
az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME

echo "Vous êtes maintenant connecté au cluster AKS : $CLUSTER_NAME"