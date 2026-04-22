#!/bin/bash

# =============================================================================
#  IPFS Gateway & RPC - Reset to Defaults (Option 4 -> Sub 5)
#  Versión corregida para entornos GCP / No-Systemd
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
USER_HOME=$(getent passwd "$user_name" | cut -d: -f6)
IPFS_PATH="${USER_HOME}/.ipfs"
CONFIG_PATH="$IPFS_PATH/config"

# =============================================================================
#  1. DETECCIÓN ROBUSTA DE INIT
# =============================================================================
banner "Reversión de Configuración: Modo Default"

if [[ -d /run/systemd/system ]] || grep -q "systemd" <(ps -p 1 -o comm= 2>/dev/null); then
    INIT_SYSTEM="systemd"
else
    INIT_SYSTEM="unknown"
fi

if ! command -v jq &>/dev/null; then
    info "Instalando jq para edición de archivos..."
    sudo apt update && sudo apt install -y jq
fi

echo -e "  - Sistema de Init detectado: ${YELLOW}$INIT_SYSTEM${NC}"
echo -e "  ${YELLOW}Esta acción restaurará los valores de red y el Caddyfile.${NC}\n"

if ! confirm "¿Deseas proceder con la restauración?"; then
    exit 0
fi

# =============================================================================
#  2. GESTIÓN DE SERVICIO CADDY
# =============================================================================
banner "Gestión de Caddy Server"

if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    if systemctl is-active --quiet caddy; then
        info "Caddy está activo."
        if confirm "¿Deseas detener y deshabilitar Caddy?"; then
            sudo systemctl stop caddy
            sudo systemctl disable caddy
            info "Caddy desactivado."
        fi
    fi
else
    warn "No se detectó systemd. Si Caddy está corriendo, deberás detenerlo manualmente."
fi

# =============================================================================
#  3. APLICACIÓN DE CAMBIOS (IPFS & CADDYFILE)
# =============================================================================
banner "Restaurando Archivos de Configuración"

rollback() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        warn "¡Error detectado! Revirtiendo cambios en el config..."
        [ -f "${CONFIG_PATH}.bak" ] && sudo cp "${CONFIG_PATH}.bak" "$CONFIG_PATH"
    fi
    exit $exit_code
}
trap rollback ERR

# --- Backup y Parada de IPFS ---
info "Creando backup de seguridad..."
sudo cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"

if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    if systemctl is-active --quiet ipfs; then
        info "Deteniendo servicio IPFS para edición segura..."
        sudo systemctl stop ipfs
        sleep 1
    fi
fi

# --- Reset de IPFS Addresses via JQ ---
info "Restaurando .Addresses.Swarm en el .config..."

SWARM_DEFAULTS='[
  "/ip4/0.0.0.0/tcp/4001",
  "/ip6/::/tcp/4001",
  "/ip4/0.0.0.0/udp/4001/webrtc-direct",
  "/ip4/0.0.0.0/udp/4001/quic-v1",
  "/ip4/0.0.0.0/udp/4001/quic-v1/webtransport",
  "/ip6/::/udp/4001/webrtc-direct",
  "/ip6/::/udp/4001/quic-v1",
  "/ip6/::/udp/4001/quic-v1/webtransport"
]'

sudo jq --argjson swarm "$SWARM_DEFAULTS" '.Addresses.Swarm = $swarm | .API = {"HTTPHeaders": {}}' "$CONFIG_PATH" > "${CONFIG_PATH}.tmp"
sudo mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"
sudo chown "$user_name:$user_name" "$CONFIG_PATH"

# --- Reset de Caddyfile ---
info "Restaurando Caddyfile a valores de fábrica..."
CADDY_DEFAULT=$(cat <<EOF
# The Caddyfile is an easy way to configure your Caddy web server.
#
# Unless the file starts with a global options block, the first
# uncommented line is always the address of your site.
#
# To use your own domain name (with automatic HTTPS), first make
# sure your domain's A/AAAA DNS records are properly pointed to
# this machine's public IP, then replace ":80" below with your
# domain name.

:80 {
	# Set this path to your site's directory.
	root * /usr/share/caddy

	# Enable the static file server.
	file_server

	# Another common task is to set up a reverse proxy:
	# reverse_proxy localhost:8080

	# Or serve a PHP site through php-fpm:
	# php_fastcgi localhost:9000
}

# Refer to the Caddy docs for more information:
# https://caddyserver.com/docs/caddyfile
EOF
)
echo "$CADDY_DEFAULT" | sudo tee /etc/caddy/Caddyfile > /dev/null

# =============================================================================
#  4. REINICIO Y FINALIZACIÓN
# =============================================================================
banner "Reinicio de Sistema"

if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    info "Iniciando IPFS..."
    sudo systemctl start ipfs
    
    if systemctl is-enabled --quiet caddy; then
        info "Reiniciando Caddy..."
        sudo systemctl restart caddy
    fi
else
    info "Configuración de archivos completada."
    warn "Como no se detectó systemd, reinicia IPFS manualmente si es necesario."
fi

banner "¡Reversión Completada!"