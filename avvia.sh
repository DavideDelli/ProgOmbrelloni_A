#!/bin/bash
# avvia.sh – LIDO CODICI SBALLATI (macOS / Linux)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VARIABILI E COLORI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m' 

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_DIR="$SCRIPT_DIR/ProgOmbrelloni_A"
SQL_FILE="$SCRIPT_DIR/setup_database.sql"
DB_CONFIG="$PROJECT_DIR/src/main/java/it/unibg/ombrelloni/config/DatabaseManager.java"

function print_ok()   { echo -e "  [OK]    ${GREEN}$1${NC}"; }
function print_info() { echo -e "  [INFO]  ${CYAN}$1${NC}"; }
function print_warn() { echo -e "  [WARN]  ${YELLOW}$1${NC}"; }
function print_fail() { echo -e "\n  [ERRORE] ${RED}$1${NC}\n"; exit 1; }
function cmd_exists() { command -v "$1" >/dev/null 2>&1; }

function show_progress() {
    echo -ne "  [....]  $1 "
    for i in {1..5}; do echo -ne "${CYAN}.${NC}"; sleep 0.3; done
    echo -e ""
}

# Rilevamento OS
OS="$(uname -s)"
DISTRO="unknown"
PKG_MGR=""

if [ "$OS" = "Linux" ]; then
    [ -f /etc/arch-release ] && DISTRO="arch" && PKG_MGR="sudo pacman -S --needed --noconfirm"
    [ -f /etc/debian_version ] && DISTRO="debian" && PKG_MGR="sudo apt install -y"
    [ -f /etc/fedora-release ] && DISTRO="fedora" && PKG_MGR="sudo dnf install -y"
elif [ "$OS" = "Darwin" ]; then
    DISTRO="macos"
    PKG_MGR="brew install"
fi

clear
echo -e "\n  ${CYAN}=====================================================${NC}"
echo -e "   🏝️  ${CYAN}LIDO CODICI SBALLATI - Sistema Unix${NC}"
echo -e "  ${CYAN}=====================================================${NC}"
echo -e "   ${GRAY}Configurazione professionale per esame di Prog. Web${NC}\n"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [1/4] VERIFICA PREREQUISITI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${NC}[1/4] Verifica Stato Sistema (OS: $DISTRO)${NC}"
echo -e "  ${GRAY}---------------------------------------------------${NC}"

HAS_JAVA=false; cmd_exists java && HAS_JAVA=true
HAS_MVN=false;  cmd_exists mvn && HAS_MVN=true
HAS_DB=false;   (cmd_exists mysql || cmd_exists mariadb) && HAS_DB=true

[ "$HAS_JAVA" = true ] && print_ok "Java JDK:       Pronto" || print_warn "Java JDK:       Mancante"
[ "$HAS_MVN" = true ]  && print_ok "Maven:          Pronto" || print_warn "Maven:          Mancante"
[ "$HAS_DB" = true ]   && print_ok "Database:       Pronto" || print_warn "Database:       Mancante"

if [ "$HAS_JAVA" = false ] || [ "$HAS_MVN" = false ] || [ "$HAS_DB" = false ]; then
    echo ""
    read -p "  Installare i tool mancanti? [S/n] " ans
    [[ "$ans" =~ ^[Nn] ]] && exit 0
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [2/4] SETUP COMPONENTI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "\n${NC}[2/4] Installazione Dipendenze${NC}"
echo -e "  ${GRAY}---------------------------------------------------${NC}"

if [ "$HAS_JAVA" = false ]; then
    show_progress "Installazione OpenJDK 21"
    if [ "$DISTRO" = "arch" ]; then $PKG_MGR jre-openjdk jdk-openjdk;
    elif [ "$DISTRO" = "debian" ]; then sudo apt update && $PKG_MGR openjdk-21-jdk;
    else $PKG_MGR openjdk@21; fi
fi

if [ "$HAS_DB" = false ]; then
    show_progress "Installazione Database Server"
    [ "$DISTRO" = "arch" ] && $PKG_MGR mariadb || $PKG_MGR mysql
fi

# Avvio servizio
show_progress "Avvio demone database"
if [ "$DISTRO" = "macos" ]; then brew services start mysql >/dev/null 2>&1
else
    SVC_NAME="mysql"; cmd_exists mariadb && SVC_NAME="mariadb"
    if [ "$DISTRO" = "arch" ] && [ ! -d "/var/lib/mysql/mysql" ]; then
        sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql >/dev/null 2>&1
    fi
    sudo systemctl enable --now $SVC_NAME >/dev/null 2>&1
fi
sleep 2

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [3/4] DATABASE & CREDENZIALI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "\n${NC}[3/4] Database & Credenziali${NC}"
echo -e "  ${GRAY}---------------------------------------------------${NC}"

DB_USER="root"; DB_PASS=""; DB_CMD="mysql"

# Prova connessione senza password
if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
    print_ok "Connessione root riuscita (senza password)"
else
    print_warn "Rilevamento automatico fallito."
    read -p "  Inserisci Utente DB: " DB_USER
    read -sp "  Inserisci Password DB: " DB_PASS
    echo ""
fi

show_progress "Importazione dati spiaggia"
# FIX IMPORTAZIONE: usiamo il comando mysql diretto senza sudo se c'è una password
IMPORT_CMD="mysql -u$DB_USER"
[ -n "$DB_PASS" ] && IMPORT_CMD="$IMPORT_CMD -p$DB_PASS"

# Eseguiamo l'importazione e verifichiamo il risultato
$IMPORT_CMD -e "DROP DATABASE IF EXISTS my_ombrelloni; CREATE DATABASE my_ombrelloni;"
$IMPORT_CMD my_ombrelloni < "$SQL_FILE"

if [ $? -eq 0 ]; then
    print_ok "Database 'my_ombrelloni' pronto e popolato."
else
    print_fail "Errore durante l'importazione del database."
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [4/4] BUILD & DEPLOY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "\n${NC}[4/4] Build Progetto & Deploy${NC}"
echo -e "  ${GRAY}---------------------------------------------------${NC}"

# Aggiornamento DatabaseManager.java
if [ "$OS" = "Darwin" ]; then
    sed -i '' "s|USER = \".*\";|USER = \"$DB_USER\";|g" "$DB_CONFIG"
    sed -i '' "s|PASSWORD = \".*\";|PASSWORD = \"$DB_PASS\";|g" "$DB_CONFIG"
else
    sed -i "s|USER = \".*\";|USER = \"$DB_USER\";|g" "$DB_CONFIG"
    sed -i "s|PASSWORD = \".*\";|PASSWORD = \"$DB_PASS\";|g" "$DB_CONFIG"
fi

cd "$PROJECT_DIR" || print_fail "Cartella progetto non trovata."
show_progress "Compilazione Maven"
mvn clean compile -q -DskipTests

echo -e "\n  ${GREEN}=====================================================${NC}"
echo -e "   🚀 ${GREEN}LIDO PRONTO! Server in ascolto su porta 8080${NC}"
echo -e "  ${GREEN}=====================================================${NC}"
echo -e "   Vai su: http://localhost:8080/\n"

mvn tomcat7:run
