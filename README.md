Voici un exemple de fichier **README** pour expliquer votre projet de déploiement de **WordPress** et **MySQL** sur **Minikube** :

```markdown
# Déploiement de WordPress et MySQL sur Minikube

## Description du projet

Ce projet a pour objectif de déployer une instance de **WordPress** avec une base de données **MySQL** sur un cluster **Minikube** local. Les services sont exposés de manière suivante :
- **WordPress** est accessible via un service de type **NodePort**.
- **MySQL** est déployé avec un service de type **ClusterIP**.

Le déploiement est effectué dans un namespace dédié appelé `wordpress`.

## Prérequis

Avant de commencer, vous devez avoir les éléments suivants installés sur votre machine :

- [Docker](https://docs.docker.com/get-docker/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm (facultatif)](https://helm.sh/docs/intro/install/) (si vous utilisez des charts Helm)

## Étapes d'installation

### 1. Démarrer Minikube

Commencez par démarrer un cluster Minikube. Vous pouvez définir la quantité de CPU et de RAM que vous souhaitez allouer à Minikube en fonction de votre machine.

```bash
minikube start --cpus=4 --memory=8192
```

### 2. Créer le namespace `wordpress`

Créez un namespace dédié pour isoler le déploiement de WordPress et MySQL.

```bash
kubectl create namespace wordpress
```

### 3. Déployer MySQL

Créez un fichier YAML pour le déploiement de MySQL (par exemple `mysql-deployment.yaml`), contenant le service **ClusterIP** et un **PersistentVolumeClaim** pour stocker les données.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: wordpress
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
  namespace: wordpress
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
          value: mysql.wordpress.svc.cluster.local:3306
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

### 5. Accéder à WordPress

Une fois le service déployé, récupérez l'URL du service WordPress en exécutant la commande suivante :

```bash
minikube service wordpress -n wordpress
```

Cela ouvrira automatiquement votre navigateur avec l'URL pour accéder à WordPress.

### 6. Vérification

Vous pouvez vérifier que les Pods et les services sont bien déployés en exécutant les commandes suivantes :

```bash
kubectl get pods -n wordpress
kubectl get svc -n wordpress
```

```
Pour accéder à votre application WordPress déployée sur Minikube, vous pouvez suivre ces étapes en fonction du type de service que vous avez configuré pour WordPress. Puisque vous avez mentionné l'utilisation du service `NodePort`, cela vous permet d'accéder à votre application WordPress via l'adresse IP de votre machine Minikube et un port spécifique.

Voici les étapes détaillées pour accéder à WordPress :

### 1. Vérifier le Service NodePort

Tout d'abord, vérifiez que le service WordPress a bien été créé en tant que `NodePort`. Utilisez la commande suivante pour lister les services dans le namespace `wordpress` :

```bash
kubectl get svc -n wordpress
```

Cela devrait afficher une ligne similaire à ceci :

```bash
NAME            TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
wordpress-svc   NodePort   10.96.0.1     <none>        80:30007/TCP   5m
```

Dans cet exemple, le service `wordpress-svc` expose le port `80` via le port `30007` sur le nœud (port NodePort).

### 2. Obtenir l'Adresse IP de Minikube

Ensuite, récupérez l'adresse IP de Minikube, car c'est cette adresse que vous utiliserez pour accéder à l'application :

```bash
minikube ip
```

Cette commande retourne une adresse IP, par exemple `192.168.99.100`.

### 3. Accéder à l'Application WordPress

Avec l'adresse IP de Minikube et le port `NodePort` (par exemple, `30007`), vous pouvez maintenant accéder à WordPress depuis un navigateur. Tapez l'URL suivante dans la barre d'adresse de votre navigateur :

```
http://<minikube-ip>:<nodeport>
```

Par exemple, si l'adresse IP de Minikube est `192.168.99.100` et le NodePort est `30007`, l'URL sera :

```
http://192.168.99.100:30007
```

Cela devrait ouvrir l'interface d'installation initiale de WordPress.

### 4. Si le Navigateur Ne Peut Pas Accéder

Si le navigateur ne parvient pas à accéder à l'application, assurez-vous que :
- Minikube fonctionne correctement en vérifiant l'état avec `minikube status`.
- Le service est correctement configuré avec `kubectl describe svc wordpress-svc -n wordpress`.
- Aucun pare-feu ou règle de sécurité n'empêche l'accès au port `NodePort`.

### 5. Utiliser le Tunnel Minikube (Optionnel)

Si vous rencontrez des difficultés avec le `NodePort`, une alternative consiste à utiliser le tunnel de Minikube, qui permet d'exposer les services de manière plus simple. Lancez la commande suivante pour créer un tunnel :

```bash
minikube tunnel
```

Ensuite, vous pouvez accéder à WordPress via l'adresse IP de Minikube, sans avoir à spécifier le port NodePort.

---

Avec ces étapes, vous devriez être en mesure d'accéder à votre application WordPress déployée sur Minikube.