### Documentation : Automatisation du Déploiement sur AKS pour HASMATECHNOLOGIE avec GitHub Actions et ArgoCD

#### **1. Introduction**

Ce document détaille la mise en place d'une solution CI/CD pour l'entreprise **HASMA Technologies**. Le besoin spécifique est de surveiller et gérer les applications conteneurisées via un cluster **Azure Kubernetes Service (AKS)**, en assurant la disponibilité des outils de surveillance comme **Grafana**, **Prometheus**, et **Node-Exporter**. Nous utiliserons **GitHub Actions** pour automatiser les déploiements et **ArgoCD** pour la gestion continue des applications déployées via une stratégie **GitOps**.

---

#### **2. Objectif du projet**

Le projet vise à répondre au besoin de **HASMA Technologies** pour automatiser et simplifier la surveillance de son infrastructure Kubernetes en utilisant une solution CI/CD basée sur GitHub Actions, ArgoCD, et les outils de monitoring (Grafana, Prometheus, et Node-Exporter). Tous les fichiers manifestes nécessaires pour ces outils seront versionnés dans un dépôt GitHub et appliqués automatiquement sur un cluster AKS.

---

### **3. Architecture du Projet**

- **Cluster AKS** : Utilisé pour exécuter les applications conteneurisées, y compris les outils de monitoring.
- **GitHub Actions** : CI/CD pipeline pour appliquer les fichiers manifestes Kubernetes de manière automatique lors de chaque changement dans le dépôt GitHub.
- **ArgoCD** : Implémentation GitOps pour la gestion continue des applications à partir du dépôt GitHub.
- **Prometheus** : Outil de surveillance pour collecter les métriques du cluster AKS.
- **Node-Exporter** : Composant qui expose les métriques des nœuds du cluster pour Prometheus.
- **Grafana** : Outil de visualisation des métriques collectées par Prometheus.

---

### **4. Prérequis**

Avant de commencer, vous devez avoir :
1. Un compte **Azure** avec les autorisations nécessaires pour gérer des ressources AKS.
2. Un dépôt **GitHub** pour stocker les fichiers manifestes Kubernetes.
3. **Azure CLI**, **Kubectl**, et **Helm** installés localement pour interagir avec le cluster AKS.
4. **GitHub Actions** activé dans le dépôt GitHub.
5. **ArgoCD**, **Prometheus**, **Grafana**, et **Node-Exporter** installés sur le cluster AKS.

---

### **5. Étape 1 : Création du Cluster AKS**

#### **1. Créer un groupe de ressources**

```bash
az group create --name HASMAResourceGroup --location eastus
```

#### **2. Créer un cluster AKS**

```bash
az aks create --resource-group HASMAResourceGroup --name HASMACluster --node-count 3 --enable-addons monitoring --generate-ssh-keys
```

#### **3. Configurer `kubectl` pour accéder au cluster AKS**

```bash
az aks get-credentials --resource-group HASMAResourceGroup --name HASMACluster
kubectl get nodes
```

---

### **6. Étape 2 : Mise en place de GitHub Actions pour CI/CD**

Nous utiliserons **GitHub Actions** pour automatiser le déploiement des fichiers manifestes (Prometheus, Grafana, Node-Exporter).

#### **1. Générer un principal de service et `AZURE_CREDENTIALS`**

Créez un principal de service pour permettre à GitHub Actions d'accéder au cluster AKS et gérez les ressources :

```bash
az ad sp create-for-rbac --name "HASMAGithubActionSP" --role contributor --scopes /subscriptions/<subscription-id> --sdk-auth
```

Ajoutez ensuite les informations générées dans un secret GitHub appelé `AZURE_CREDENTIALS` :

```json
{
  "clientId": "<azure-client-id>",
  "clientSecret": "<azure-client-secret>",
  "subscriptionId": "<azure-subscription-id>",
  "tenantId": "<azure-tenant-id>",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/"
}
```

#### **2. Configuration du fichier GitHub Actions**

Créez le fichier `.github/workflows/deploy.yml` pour automatiser le déploiement des manifestes sur AKS :

```yaml
name: CI/CD Pipeline for HASMATECHNOLOGIE
name: CI/CD Pipeline

on:
  push:
    branches:
      - main

jobs:
  deploy_k8s:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Install dependencies
        run: sudo apt-get update && sudo apt-get install -y gettext

      - name: Set up kubectl
        uses: azure/setup-kubectl@v1
        with:
          version: 'latest'

      - name: Authenticate to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Configure Kubernetes context
        run: |
          az aks get-credentials --resource-group Abdel_ressource --name Abdel_cluster --overwrite-existing

      - name: Prepare K8s Deployment
        run: |
          # Appliquer les fichiers de configuration pour WordPress
          kubectl apply -f ./Front
          kubectl apply -f ./Back/Phpmyadmin
          kubectl apply -f ./Monitoring/Grafana
          kubectl apply -f ./Monitoring/Prometheus
          kubectl apply -f ./Monitoring/node-exporter  --validate=false        
```

### **7. Étape 3 : Installation et Configuration d'ArgoCD**

**ArgoCD** sera utilisé pour synchroniser les déploiements Kubernetes à partir du dépôt GitHub.

#### **1. Installation d'ArgoCD**

Créez un namespace et installez ArgoCD :

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

#### **2. Accéder à ArgoCD**

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Accédez à l'interface **https://localhost:8080**. Récupérez le mot de passe initial :

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

#### **3. Configurer l'application ArgoCD**

Créez une application dans ArgoCD pour surveiller le dépôt GitHub :

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hasma-monitoring
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/HASMA-Technologies/monitoring-stack.git'
    targetRevision: main
    path: k8s
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Cette configuration permet à **ArgoCD** de surveiller le dépôt GitHub et d'appliquer automatiquement les mises à jour du cluster AKS.

---

### **8. Étape 4 : Installation de Prometheus, Grafana, et Node-Exporter**

Ces outils sont déployés via **Helm**, qui gère leur installation sur le cluster AKS.

#### **1. Installer Prometheus, Grafana, et Node-Exporter**

Ajoutez le dépôt **Prometheus Community** et installez la stack de monitoring via Helm :

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Installer la stack de monitoring
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```

#### **2. Accéder à Grafana**

Une fois Grafana installé, vous pouvez accéder à l'interface web de Grafana en configurant un **port-forward** :

```bash
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
```

Accédez ensuite à **http://localhost:3000** dans votre navigateur. Les identifiants par défaut sont :
- **Username** : `admin`
- **Password** : `prom-operator`

#### **3. Configurer les Dashboards Grafana**

Grafana est préconfiguré pour se connecter à Prometheus et afficher des dashboards avec les métriques collectées. Vous pouvez importer ou créer des dashboards pour visualiser les performances et la santé des nœuds et des pods.

---

### **9. Étape 5 : Surveillance et Validation**

#### **1. Vérifier les métriques Prometheus**

Assurez-vous que **Prometheus** collecte correctement les métriques du cluster en accédant à l'interface de Prometheus :

```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
```

Accédez à **http://localhost:9090** et interrogez les métriques exposées.

#### **2. Accéder à Grafana pour visualiser les métriques**

Assurez-vous que **Grafana** affiche correctement les dashboards avec les métriques collectées par Prometheus et exposées par **Node-Exporter**. Utilisez les dashboards fournis ou créez-en de nouveaux en fonction des besoins spécifiques de l'infrastructure de **HASMA Technologies**.

---

### **10. Conclusion**

Le projet d'intégration continue et de déploiement continu (CI/CD) mis en place pour