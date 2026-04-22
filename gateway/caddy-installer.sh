#!/bin/bash

# =============================================================================
#  IPFS Gateway - Caddy Installation (Option 4 -> Sub 1)
# =============================================================================

set -euo pipefail

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;97m'
NC='\033[0m'

# --- Funciones Visuales ---
banner() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════╗"
    printf "║  %-60s║\n" "$1"
    echo -e "╚══════════════════════════════════════════════════════════════╝${NC}\n"
}
info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
confirm() { local _r; read -p "$(echo -e "${YELLOW}[?]${NC} $1 [s/N]: ")" _r; [[ "${_r,,}" == "s" ]]; }

# --- Variables de Contexto ---
user_name="${IPFS_USER:-${SUDO_USER:-$USER}}"
DATE=$(date +"%Y%m%d-%H%M")

# =============================================================================
#  1. ANÁLISIS DE INSTALACIÓN (Idempotencia)
# =============================================================================
banner "Análisis de Caddy Server"

if command -v caddy &>/dev/null; then
    CADDY_VER=$(caddy version | awk '{print $1}')
    info "Caddy ya está presente en el sistema."
    echo -e "  - Versión: ${CYAN}$CADDY_VER${NC}"
    
    if systemctl is-active --quiet caddy; then
        echo -e "  - Estado:  ${GREEN}Servicio Activo${NC}"
    else
        echo -e "  - Estado:  ${RED}Servicio Inactivo/Detenido${NC}"
    fi
    echo ""
    if ! confirm "¿Deseas forzar la reinstalación o actualizar repositorios?"; then
        info "Saltando instalación. Caddy ya está listo."
        exit 0
    fi
else
    info "Caddy no detectado. Iniciando proceso de instalación oficial..."
fi

# =============================================================================
#  2. CONFIGURACIÓN DE REPOSITORIOS
# =============================================================================
banner "Configurando Repositorios"

info "Instalando dependencias de transporte y llaves..."
sudo apt update
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

# Instalación de la llave oficial de Caddy
if [ ! -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg ]; then
    info "Descargando llave GPG de Caddy..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
    sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes
fi

# Configuración del source list
if [ ! -f /etc/apt/sources.list.d/caddy-stable.list ]; then
    info "Agregando repositorio oficial a sources.list.d..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
    sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
fi

# =============================================================================
#  3. INSTALACIÓN DEL BINARIO
# =============================================================================
banner "Ejecutando Instalación"

info "Actualizando índices de paquetes..."
sudo apt update

info "Instalando Caddy..."
sudo apt install -y caddy

# =============================================================================
#  4. GESTIÓN DEL SERVICIO
# =============================================================================
banner "Configuración de Servicio"

if [[ -d /run/systemd/system ]]; then
    info "Habilitando Caddy en Systemd para arranque automático..."
    sudo systemctl enable caddy
    sudo systemctl start caddy
    
    # Verificación rápida
    if systemctl is-active --quiet caddy; then
        info "Servicio Caddy: ${GREEN}OK${NC}"
    else
        warn "Caddy instalado pero el servicio no inició. Verifica con 'journalctl -u caddy'"
    fi
else
    warn "Systemd no detectado. Deberás iniciar Caddy manualmente:"
    echo -e "${CYAN}  sudo caddy run --config /etc/caddy/Caddyfile &${NC}"
fi

# =============================================================================
#  5. FINALIZACIÓN
# =============================================================================
banner "¡Caddy Instalado!"
info "El binario está listo en: ${CYAN}$(which caddy)${NC}"
info "Versión: ${GREEN}$(caddy version | awk '{print $1}')${NC}"
echo ""
info "Nota: El Caddyfile en /etc/caddy/Caddyfile se mantiene intacto."
info "Usa las siguientes subopciones para configurar el Proxy Inverso y CORS."