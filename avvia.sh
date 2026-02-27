#!/bin/bash
# avvia.sh – LIDO CODICI SBALLATI (macOS / Linux)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VARIABILI E COLORI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_DIR="$SCRIPT_DIR/ProgOmbrelloni_A"
SQL_FILE="$SCRIPT_DIR/setup_database.sql"
DB_CONFIG="$PROJECT_DIR/src/main/java/it/unibg/ombrelloni/config/DatabaseManager.java"

function print_ok()   { echo -e "  [OK]    ${GREEN}$1${NC}"; }
function print_info() { echo -e "  [INFO]  ${CYAN}$1${NC}"; }
function print_warn() { echo -e "  [WARN]  ${YELLOW}$1${NC}"; }
function print_fail() { echo -e "\n  [ERRORE] ${RED}$1${NC}\n"; exit 1; }
function cmd_exists() { command -v "$1" >/dev/null 2>&1; }

# Rilevamento OS e Distro
OS="$(uname -s)"
DISTRO="unknown"
PKG_MGR=""

if [ "$OS" = "Linux" ]; then
    if [ -f /etc/arch-release ]; then
        DISTRO="arch"
        PKG_MGR="sudo pacman -S --needed --noconfirm"
    elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
        DISTRO="fedora"
        PKG_MGR="sudo dnf install -y"
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        PKG_MGR="sudo apt install -y"
    fi
elif [ "$OS" = "Darwin" ]; then
    DISTRO="macos"
    if cmd_exists brew; then
        PKG_MGR="brew install"
    else
        print_fail "Homebrew non trovato. Installalo da https://brew.sh/ e riprova."
    fi
fi

clear
echo -e "\n  ${CYAN}=====================================================${NC}"
echo -e "   LIDO CODICI SBALLATI - Avvio automatico Unix"
echo -e "  ${CYAN}=====================================================${NC}\n"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FASE 1 – Controlla prerequisiti
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "[1/4] Verifica prerequisiti OS: $DISTRO"
echo "  ---------------------------------------------------"

HAS_JAVA=false; cmd_exists java && HAS_JAVA=true
HAS_MVN=false;  cmd_exists mvn && HAS_MVN=true
HAS_DB=false;   (cmd_exists mysql || cmd_exists mariadb) && HAS_DB=true

[ "$HAS_JAVA" = true ] && print_ok "Java trovato" || print_warn "Java mancante -> verrà installato"
[ "$HAS_MVN" = true ]  && print_ok "Maven trovato" || print_warn "Maven mancante -> verrà installato"
[ "$HAS_DB" = true ]   && print_ok "Database trovato" || print_warn "MySQL/MariaDB mancante -> verrà installato"

if [ ! -d "$PROJECT_DIR" ]; then print_fail "Cartella ProgOmbrelloni_A non trovata!"; fi
if [ ! -f "$SQL_FILE" ]; then print_fail "File setup_database.sql non trovato!"; fi

if [ "$HAS_JAVA" = false ] || [ "$HAS_MVN" = false ] || [ "$HAS_DB" = false ]; then
    echo ""
    read -p "  I tool mancanti verranno installati. Potrebbe essere richiesta la password di root. Continuare? [S/n] " ans
    case $ans in
        [Nn]* ) exit 0;;
    esac
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FASE 2 – Installa e Configura Servizi
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "\n[2/4] Installazione componenti"
echo "  ---------------------------------------------------"

if [ "$HAS_JAVA" = false ]; then
    print_info "Installazione OpenJDK..."
    if [ "$DISTRO" = "arch" ]; then $PKG_MGR jre-openjdk jdk-openjdk;
    elif [ "$DISTRO" = "fedora" ]; then $PKG_MGR java-21-openjdk-devel;
    elif [ "$DISTRO" = "debian" ]; then sudo apt update && $PKG_MGR openjdk-21-jdk;
    elif [ "$DISTRO" = "macos" ]; then $PKG_MGR openjdk@21; fi
    cmd_exists java || print_fail "Installazione Java fallita."
    print_ok "Java installato."
fi

if [ "$HAS_MVN" = false ]; then
    print_info "Installazione Maven..."
    $PKG_MGR maven || print_fail "Installazione Maven fallita."
    print_ok "Maven installato."
fi

if [ "$HAS_DB" = false ]; then
    print_info "Installazione Database Server..."
    if [ "$DISTRO" = "arch" ]; then $PKG_MGR mariadb;
    elif [ "$DISTRO" = "fedora" ]; then $PKG_MGR mariadb-server;
    elif [ "$DISTRO" = "debian" ]; then $PKG_MGR mysql-server;
    elif [ "$DISTRO" = "macos" ]; then $PKG_MGR mysql; fi
    print_ok "Pacchetto Database installato."
fi

# Gestione Demone Database
print_info "Controllo demone database in background..."
if [ "$DISTRO" = "macos" ]; then
    brew services start mysql >/dev/null 2>&1
else
    # Inizializzazione specifica per Arch/MariaDB se la cartella dati è vuota
    if [ "$DISTRO" = "arch" ] && [ ! -d "/var/lib/mysql/mysql" ]; then
        print_info "Inizializzazione database di sistema (MariaDB)..."
        sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql >/dev/null 2>&1
    fi
    
    SVC_NAME="mysql"
    cmd_exists mariadb && SVC_NAME="mariadb"
    
    sudo systemctl enable --now $SVC_NAME >/dev/null 2>&1
fi
sleep 2 # Tempo tecnico per permettere al socket di aprirsi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FASE 3 – Configurazione Database
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "\n[3/4] Configurazione database"
echo "  ---------------------------------------------------"

DB_PORT="3306"
DB_USER=""
DB_PASS=""
DB_CMD="mysql"

# Prova accesso senza password (comune su Linux con sudo o default locale)
if sudo $DB_CMD -u root -e "SELECT 1;" >/dev/null 2>&1; then
    DB_USER="root"
    print_ok "Connessione riuscita come root (senza password)"
elif $DB_CMD -u root -proot -e "SELECT 1;" >/dev/null 2>&1; then
    DB_USER="root"
    DB_PASS="root"
    print_ok "Connessione riuscita come root (password: root)"
else
    print_warn "Accesso root automatico fallito. Inserisci le credenziali locali."
    read -p "  Utente DB: " DB_USER
    read -sp "  Password DB (invio = vuota): " DB_PASS
    echo ""
    if ! $DB_CMD -u"$DB_USER" ${DB_PASS:+"-p$DB_PASS"} -e "SELECT 1;" >/dev/null 2>&1; then
        print_fail "Credenziali errate o servizio non avviato."
    fi
fi

print_info "Importazione setup_database.sql..."
if ! sudo $DB_CMD -u"$DB_USER" ${DB_PASS:+"-p$DB_PASS"} < "$SQL_FILE" >/dev/null 2>&1; then
    print_warn "Database già esistente. Ricreazione in corso..."
    sudo $DB_CMD -u"$DB_USER" ${DB_PASS:+"-p$DB_PASS"} -e "DROP DATABASE IF EXISTS my_ombrelloni;"
    sudo $DB_CMD -u"$DB_USER" ${DB_PASS:+"-p$DB_PASS"} < "$SQL_FILE" || print_fail "Importazione fallita."
fi
print_ok "Database pronto."

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FASE 4 – Compilazione e avvio
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "\n[4/4] Compilazione e avvio"
echo "  ---------------------------------------------------"

print_info "Aggiornamento file DatabaseManager.java..."
# macOS usa la versione BSD di sed, Linux usa GNU sed.
if [ "$OS" = "Darwin" ]; then
    sed -i '' "s|jdbc:mysql://localhost:[0-9]*/my_ombrelloni|jdbc:mysql://localhost:${DB_PORT}/my_ombrelloni|g" "$DB_CONFIG"
    sed -i '' "s|private static final String USER = \".*\";|private static final String USER = \"$DB_USER\";|g" "$DB_CONFIG"
    sed -i '' "s|private static final String PASSWORD = \".*\";|private static final String PASSWORD = \"$DB_PASS\";|g" "$DB_CONFIG"
else
    sed -i "s|jdbc:mysql://localhost:[0-9]*/my_ombrelloni|jdbc:mysql://localhost:${DB_PORT}/my_ombrelloni|g" "$DB_CONFIG"
    sed -i "s|private static final String USER = \".*\";|private static final String USER = \"$DB_USER\";|g" "$DB_CONFIG"
    sed -i "s|private static final String PASSWORD = \".*\";|private static final String PASSWORD = \"$DB_PASS\";|g" "$DB_CONFIG"
fi
print_ok "Configurazione Java aggiornata."

cd "$PROJECT_DIR" || exit
print_info "Compilazione Maven in corso..."
mvn clean compile -q || print_fail "Compilazione fallita."
print_ok "Compilazione completata."

echo -e "\n  ${GREEN}=====================================================${NC}"
echo -e "  ${GREEN} Applicazione avviata!${NC}\n"
echo -e "   Aprire il browser su:  http://localhost:8080/\n"
echo -e "   Credenziali di test:"
echo -e "     Cliente:        CLIENTE0001  (Mario Rossi)"
echo -e "     Amministratore: admin123\n"
echo -e "   Per fermare il server: premi Ctrl+C"
echo -e "  ${GREEN}=====================================================${NC}\n"

mvn tomcat7:run