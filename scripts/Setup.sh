#!/bin/bash

# ================================================
# SCRIPT D'INSTALLATION AUTOMATIQUE - ELK STACK
# Firefox Build Log Monitoring
# ================================================

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions d'affichage
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Fonction de vérification des prérequis
check_prerequisites() {
    print_header "Vérification des Prérequis"
    
    local all_ok=true
    
    # Vérifier Docker
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        print_success "Docker installé (version $DOCKER_VERSION)"
    else
        print_error "Docker n'est pas installé"
        print_info "Installer Docker depuis: https://www.docker.com/products/docker-desktop"
        all_ok=false
    fi
    
    # Vérifier Docker Compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
        print_success "Docker Compose installé (version $COMPOSE_VERSION)"
    else
        print_error "Docker Compose n'est pas installé"
        all_ok=false
    fi
    
    # Vérifier que Docker est en cours d'exécution
    if docker info &> /dev/null; then
        print_success "Docker daemon en cours d'exécution"
    else
        print_error "Docker daemon n'est pas en cours d'exécution"
        print_info "Démarrer Docker Desktop ou le service Docker"
        all_ok=false
    fi
    
    # Vérifier la RAM disponible (Linux)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
        if [ "$TOTAL_MEM" -lt 8 ]; then
            print_warning "RAM totale: ${TOTAL_MEM}GB (8GB recommandés)"
        else
            print_success "RAM disponible: ${TOTAL_MEM}GB"
        fi
    fi
    
    # Vérifier l'espace disque
    AVAILABLE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt 10 ]; then
        print_warning "Espace disque: ${AVAILABLE_SPACE}GB (10GB recommandés)"
    else
        print_success "Espace disque: ${AVAILABLE_SPACE}GB"
    fi
    
    echo ""
    
    if [ "$all_ok" = false ]; then
        print_error "Veuillez installer les prérequis manquants avant de continuer"
        exit 1
    fi
}

# Fonction de configuration de l'environnement
setup_environment() {
    print_header "Configuration de l'Environnement"
    
    # Copier .env.example vers .env si non existant
    if [ ! -f .env ]; then
        print_info "Création du fichier .env..."
        cp .env.example .env
        print_success "Fichier .env créé"
        print_warning "Pensez à éditer .env pour personnaliser la configuration"
    else
        print_info "Fichier .env existant - non modifié"
    fi
    
    # Créer le répertoire logs si non existant
    if [ ! -d "logs" ]; then
        print_info "Création du répertoire logs/..."
        mkdir -p logs
        touch logs/.gitkeep
        print_success "Répertoire logs/ créé"
        print_warning "Placez vos fichiers .txt dans logs/ avant de démarrer"
    else
        print_info "Répertoire logs/ existant"
    fi
    
    echo ""
}

# Fonction de configuration système (Linux)
configure_system() {
    print_header "Configuration Système"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Augmenter vm.max_map_count pour Elasticsearch
        CURRENT_VALUE=$(sysctl -n vm.max_map_count)
        REQUIRED_VALUE=262144
        
        if [ "$CURRENT_VALUE" -lt "$REQUIRED_VALUE" ]; then
            print_info "Configuration de vm.max_map_count pour Elasticsearch..."
            
            if [ "$EUID" -eq 0 ]; then
                sysctl -w vm.max_map_count=$REQUIRED_VALUE
                print_success "vm.max_map_count configuré"
            else
                print_warning "Privilèges sudo requis pour configurer vm.max_map_count"
                sudo sysctl -w vm.max_map_count=$REQUIRED_VALUE
                print_success "vm.max_map_count configuré"
            fi
        else
            print_success "vm.max_map_count déjà configuré ($CURRENT_VALUE)"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "macOS détecté - vm.max_map_count géré par Docker Desktop"
    fi
    
    echo ""
}

# Fonction de démarrage de la pile ELK
start_elk_stack() {
    print_header "Démarrage de la Pile ELK"
    
    print_info "Pull des images Docker..."
    docker-compose pull
    
    print_info "Démarrage des services..."
    docker-compose up -d
    
    print_success "Services démarrés"
    echo ""
    
    # Afficher le statut
    print_info "Statut des services:"
    docker-compose ps
    
    echo ""
}

# Fonction d'attente de disponibilité
wait_for_services() {
    print_header "Attente de la Disponibilité des Services"
    
    local max_wait=120  # 2 minutes max
    local elapsed=0
    
    print_info "Attente d'Elasticsearch..."
    while ! curl -s http://localhost:9200/_cluster/health &> /dev/null; do
        if [ $elapsed -ge $max_wait ]; then
            print_error "Elasticsearch ne répond pas après ${max_wait}s"
            print_info "Vérifier les logs: docker-compose logs elasticsearch"
            exit 1
        fi
        printf "."
        sleep 5
        elapsed=$((elapsed + 5))
    done
    print_success "Elasticsearch opérationnel"
    
    print_info "Attente de Kibana..."
    elapsed=0
    while ! curl -s http://localhost:5601/api/status &> /dev/null; do
        if [ $elapsed -ge $max_wait ]; then
            print_error "Kibana ne répond pas après ${max_wait}s"
            print_info "Vérifier les logs: docker-compose logs kibana"
            exit 1
        fi
        printf "."
        sleep 5
        elapsed=$((elapsed + 5))
    done
    print_success "Kibana opérationnel"
    
    echo ""
}

# Fonction de vérification post-installation
post_installation_check() {
    print_header "Vérification Post-Installation"
    
    # Vérifier la santé d'Elasticsearch
    ES_HEALTH=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$ES_HEALTH" = "green" ] || [ "$ES_HEALTH" = "yellow" ]; then
        print_success "Cluster Elasticsearch: $ES_HEALTH"
    else
        print_warning "Cluster Elasticsearch: $ES_HEALTH"
    fi
    
    # Vérifier les index
    INDEX_COUNT=$(curl -s http://localhost:9200/_cat/indices | wc -l)
    print_info "Nombre d'index créés: $INDEX_COUNT"
    
    echo ""
}

# Fonction d'affichage des informations finales
print_final_info() {
    print_header "🎉 Installation Terminée avec Succès"
    
    echo -e "${GREEN}Votre pile ELK est maintenant opérationnelle !${NC}"
    echo ""
    echo -e "${BLUE}Accès aux services:${NC}"
    echo -e "  🌐 Kibana:        ${GREEN}http://localhost:5601${NC}"
    echo -e "  🔍 Elasticsearch: ${GREEN}http://localhost:9200${NC}"
    echo -e "  📊 Logstash API:  ${GREEN}http://localhost:9600${NC}"
    echo ""
    echo -e "${BLUE}Prochaines étapes:${NC}"
    echo -e "  1. Placer vos fichiers .txt dans le dossier ${YELLOW}logs/${NC}"
    echo -e "  2. Ouvrir Kibana: ${GREEN}http://localhost:5601${NC}"
    echo -e "  3. Aller dans ${YELLOW}Discover${NC} pour voir vos logs"
    echo -e "  4. Créer votre dashboard"
    echo ""
    echo -e "${BLUE}Commandes utiles:${NC}"
    echo -e "  Voir les logs:    ${YELLOW}docker-compose logs -f${NC}"
    echo -e "  Arrêter:          ${YELLOW}docker-compose down${NC}"
    echo -e "  Redémarrer:       ${YELLOW}docker-compose restart${NC}"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo -e "  README:     ${YELLOW}cat README.md${NC}"
    echo -e "  Quickstart: ${YELLOW}cat QUICKSTART.md${NC}"
    echo ""
}

# ================================================
# PROGRAMME PRINCIPAL
# ================================================

main() {
    clear
    
    print_header "🚀 Installation ELK Stack - Firefox Build Logs"
    echo ""
    
    # Étape 1: Vérifier les prérequis
    check_prerequisites
    
    # Étape 2: Configuration de l'environnement
    setup_environment
    
    # Étape 3: Configuration système
    configure_system
    
    # Étape 4: Démarrer la pile
    start_elk_stack
    
    # Étape 5: Attendre que les services soient prêts
    wait_for_services
    
    # Étape 6: Vérification post-installation
    post_installation_check
    
    # Étape 7: Afficher les infos finales
    print_final_info
}

# Exécuter le programme principal
main