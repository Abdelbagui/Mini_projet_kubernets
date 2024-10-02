```markdown
# Déploiement de WordPress et MySQL sur Minikube

## Description du projet

Ce projet a pour objectif de déployer une instance de **WordPress** avec une base de données **MySQL** sur un cluster **Minikube** local. Les services sont exposés de manière suivante :
- **WordPress** est accessible via un service de type **NodePort**.
- **MySQL** est déployé avec un service de type **ClusterIP**.

Le déploiement est effectué dans un namespace dédié appelé `web-stack`. De plus, nous mettons en place un système de monitoring utilisant **Prometheus** et **Grafana**.

## Prérequis

Avant de commencer, vous devez avoir les éléments suivants installés sur votre machine :

- [Docker](https://docs.docker.com/get-docker/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)


## Étapes d'installation

### 1. Démarrer Minikube

Commencez par démarrer un cluster Minikube. Vous pouvez définir la quantité de CPU et de RAM que vous souhaitez allouer à Minikube en fonction de votre machine.

```bash
minikube start --cpus=4 --memory=8192
```

### 2. Créer le namespace `web-stack`

Créez un namespace dédié pour isoler le déploiement de WordPress et MySQL.

```bash
kubectl create namespace web-stack
```

### 3. Déployer MySQL

Créez un fichier YAML pour le déploiement de MySQL (par exemple `mysql-deployment.yaml`), contenant le service **ClusterIP** et un **PersistentVolumeClaim** pour stocker les données.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: web-stack
spec:
  selector:
    matchLabels:
      app: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - image: mysql:5.7
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-root-password
        - name: MYSQL_DATABASE
          value: "wordpress"
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-pv-claim
```

Appliquez ce fichier :

```bash
kubectl apply -f mysql-deployment.yaml
```

### 4. Déployer WordPress

Créez un fichier YAML pour le déploiement de WordPress (par exemple `wordpress-deployment.yaml`), exposé via un service **NodePort**.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: web-stack
spec:
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - image: wordpress:4.8-apache
        name: wordpress
        env:
        - name: WORDPRESS_DB_HOST
          value: mysql.web-stack.svc.cluster.local:3306
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-root-password
        ports:
        - containerPort: 80
        volumeMounts:
        - name: wordpress-persistent-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-persistent-storage
        persistentVolumeClaim:
          claimName: wordpress-pv-claim
```

Appliquez ce fichier :

```bash
kubectl apply -f wordpress-deployment.yaml
```

### 5. Déployer Prometheus et Grafana

Pour surveiller votre application, vous allez déployer **Prometheus** et **Grafana**. Créez les fichiers suivants :

#### Prometheus Deployment

Créez un fichier YAML pour le déploiement de Prometheus (par exemple `prometheus-deployment.yaml`).

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: web-stack
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus/
        - name: prometheus-data
          mountPath: /prometheus
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
      volumes:
      - name: prometheus-data
        persistentVolumeClaim:
          claimName: prometheus-pvc
      - name: prometheus-config
        configMap:
          name: prometheus-config
```

Créez également un `ConfigMap` pour la configuration de Prometheus (par exemple `prometheus-config.yaml`).

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: web-stack
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'node-exporter'
        static_configs:
          - targets: ['node-exporter.web-stack.svc.cluster.local:9100']
```

Appliquez les fichiers :

```bash
kubectl apply -f prometheus-config.yaml
kubectl apply -f prometheus-deployment.yaml
```

#### Grafana Deployment

Créez un fichier YAML pour le déploiement de Grafana (par exemple `grafana-deployment.yaml`).

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: web-stack
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
      volumes:
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-pvc
```

Appliquez ce fichier :

```bash
kubectl apply -f grafana-deployment.yaml
```

### 6. Accéder à WordPress

Une fois le service déployé, récupérez l'URL du service WordPress en exécutant la commande suivante :

```bash
minikube service wordpress -n web-stack
```

Cela ouvrira automatiquement votre navigateur avec l'URL pour accéder à WordPress.

### 7. Accéder à Grafana et Prometheus

Pour accéder à Grafana et Prometheus, utilisez les commandes suivantes :

- Pour Grafana :

```bash
minikube service grafana -n web-stack
```

- Pour Prometheus :

```bash
minikube service prometheus -n web-stack
```

### 8. Vérification

Vous pouvez vérifier que les Pods et les services sont bien déployés en exécutant les commandes suivantes :

```bash
kubectl get pods -n web-stack
kubectl get svc -n web-stack
```

