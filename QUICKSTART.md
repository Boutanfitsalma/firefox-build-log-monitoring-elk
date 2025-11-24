# ⚡ Guide de Démarrage Rapide - 5 Minutes

Ce guide vous permettra de lancer la pile ELK en moins de 5 minutes.

---

## 📋 Prérequis

Avant de commencer, assurez-vous d'avoir :

- ✅ **Docker** installé ([Télécharger](https://www.docker.com/products/docker-desktop))
- ✅ **Docker Compose** installé (inclus avec Docker Desktop)
- ✅ **8 GB RAM minimum** disponible
- ✅ **10 GB d'espace disque** libre

### Vérifier l'installation

```bash
docker --version
# Docker version 20.10.17 ou supérieur

docker-compose --version
# docker-compose version 1.29.2 ou supérieur
```

---

## 🚀 Installation en 5 Étapes

### Étape 1️⃣ : Cloner le Projet

```bash
git clone https://github.com/Boutanfitsalma/firefox-build-log-monitoring-elk.git
cd firefox-build-log-monitoring-elk
```

### Étape 2️⃣ : Configurer l'Environnement

```bash
# Copier le fichier d'environnement

```

### Étape 3️⃣ : Préparer le Répertoire des Logs

```bash
# Créer le dossier pour les logs
mkdir -p logs

# Ajouter un fichier .gitkeep pour garder le dossier dans Git
touch logs/.gitkeep
```

**Important** : Placer vos fichiers de logs `.txt` dans le dossier `logs/` avant de démarrer.

### Étape 4️⃣ : Démarrer la Pile ELK

```bash
# Démarrer tous les services en arrière-plan
docker-compose up -d

# Vérifier que tout est opérationnel
docker-compose ps
```

**Sortie attendue** :

```
NAME                COMMAND                  SERVICE             STATUS
elasticsearch       "/bin/tini -- /usr/l…"   elasticsearch       Up (healthy)
filebeat            "/usr/bin/docker-ent…"   filebeat            Up
kibana              "/bin/tini -- /usr/l…"   kibana              Up
logstash            "/usr/local/bin/dock…"   logstash            Up
```

### Étape 5️⃣ : Accéder à Kibana

```bash
# Attendre 30-60 secondes que Kibana soit prêt
# Puis ouvrir dans le navigateur :
```

🌐 **Kibana** : http://localhost:5601

---

## 🎯 Vérifications Post-Démarrage

### 1. Vérifier Elasticsearch

```bash
curl http://localhost:9200/_cluster/health?pretty
```

**Réponse attendue** : `"status" : "green"` ou `"yellow"`

### 2. Vérifier les Index Créés

```bash
curl http://localhost:9200/_cat/indices?v
```

Vous devriez voir un index `firefox-logs-*`.

### 3. Vérifier Filebeat

```bash
docker-compose logs filebeat | tail -20
```

Chercher des lignes comme :
```
INFO    [publisher_pipeline_output]    pipeline/output.go:143    Connection to backoff(async(tcp://logstash:5044)) established
```

### 4. Accéder au Dashboard Kibana

1. Aller sur http://localhost:5601
2. Cliquer sur le menu ☰ (hamburger)
3. Aller dans **Analytics** > **Discover**
4. Sélectionner l'index pattern `firefox-logs-*`
5. Vous devriez voir vos logs !

---

## 📊 Créer votre Premier Dashboard

### Méthode 1 : Import Automatique (Recommandé)

Si vous avez un export de dashboard :

1. Aller dans **Stack Management** > **Saved Objects**
2. Cliquer sur **Import**
3. Sélectionner le fichier `dashboard-export.ndjson`
4. Cliquer sur **Import**

### Méthode 2 : Création Manuelle

1. Aller dans **Analytics** > **Dashboard**
2. Cliquer sur **Create dashboard**
3. Cliquer sur **Create visualization**
4. Choisir le type de visualisation (ex: **Metric**)
5. Configurer la visualisation
6. Sauvegarder

**Visualisations recommandées** :
- **Metric** : Nombre total de logs
- **Pie Chart** : Répartition des statuts
- **Line Chart** : Volume dans le temps
- **Data Table** : Top fichiers actifs

---

## 🔍 Activer la Détection d'Anomalies

### Prérequis

⚠️ **Important** : La détection d'anomalies nécessite une **licence Basic (gratuite)** d'Elasticsearch.

### Activation

1. Aller dans **Machine Learning** dans le menu Kibana
2. Cliquer sur **Create new job**
3. Sélectionner **Advanced job**
4. Configurer :
   - **Index pattern** : `firefox-logs-*`
   - **Detector** : `count`
   - **Partition field** : `log.file.path.keyword`
   - **Bucket span** : `15m`
5. Cliquer sur **Create job**
6. Cliquer sur **Start**

### Visualiser les Anomalies

1. Aller dans **Machine Learning** > **Anomaly Explorer**
2. Sélectionner votre job
3. Explorer les anomalies détectées

---

## 🛑 Arrêter la Pile

```bash
# Arrêter tous les services
docker-compose down

# Arrêter ET supprimer les volumes (⚠️ perte de données)
docker-compose down -v
```

---

## 🔄 Redémarrer la Pile

```bash
# Démarrer
docker-compose up -d

# Redémarrer un service spécifique
docker-compose restart logstash
```

---

## 🐛 Problèmes Courants

### Problème 1 : "Port already in use"

**Erreur** : `Bind for 0.0.0.0:9200 failed: port is already allocated`

**Solution** :
```bash
# Trouver le processus qui utilise le port
# Windows
netstat -ano | findstr :9200

# Linux/Mac
lsof -i :9200

# Tuer le processus ou changer le port dans .env
```

### Problème 2 : Elasticsearch ne démarre pas

**Erreur** : `max virtual memory areas vm.max_map_count [65530] is too low`

**Solution** :

**Linux/Mac** :
```bash
sudo sysctl -w vm.max_map_count=262144
```

**Windows (WSL2)** :
```powershell
wsl -d docker-desktop
sysctl -w vm.max_map_count=262144
```

### Problème 3 : Filebeat ne trouve pas les logs

**Symptôme** : Aucun log dans Kibana

**Solution** :
1. Vérifier que les fichiers `.txt` sont bien dans `./logs/`
2. Vérifier les permissions :
   ```bash
   chmod -R 755 logs/
   ```
3. Regarder les logs Filebeat :
   ```bash
   docker-compose logs filebeat
   ```

### Problème 4 : "Out of memory"

**Symptôme** : Services qui crashent

**Solution** :
1. Augmenter la RAM allouée à Docker (Settings > Resources)
2. Réduire la mémoire JVM dans `.env` :
   ```bash
   ES_JAVA_OPTS=-Xms256m -Xmx256m
   LS_JAVA_OPTS=-Xms128m -Xmx128m
   ```

---

## 📚 Étapes Suivantes

Maintenant que votre pile ELK fonctionne :

1. 📖 Lire le [README complet](README.md)
2. 🏗️ Explorer l'[Architecture détaillée](docs/ARCHITECTURE.md)
3. 📊 Consulter le [Rapport PDF](docs/Rapport_Projet_ELK.pdf)


---

