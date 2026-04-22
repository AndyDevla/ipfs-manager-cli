#!/bin/bash

# =============================================================================
#  IPFS Gateway & SSL Configuration - Cold Fix (Option 4 -> Sub 2)
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
DATE=$(date +"%Y%m%d-%H%M")

# =============================================================================
#  1. ANÁLISIS DE REQUISITOS
# =============================================================================
banner "Análisis de Requisitos: Gateway SSL"

if ! command -v caddy &>/dev/null; then
    warn "Caddy no está instalado. Ejecuta la Subopción 1 primero."
    exit 1
fi

if ! command -v jq &>/dev/null; then
    info "Instalando jq para edición de archivos..."
    sudo apt update && sudo apt install -y jq
fi

# =============================================================================
#  2. RECOLECCIÓN DE DATOS
# =============================================================================
read -p "  🌐 Ingresa el dominio para el Gateway: " DOMAIN

if [[ -z "$DOMAIN" ]]; then
    warn "El dominio es obligatorio."
    exit 1
fi

echo -e "\n  ${YELLOW}┌─────────────────────────────────────────────┐"
printf "  │  %-43s│\n" "RESUMEN DE OPERACIÓN (MODO SEGURO)"
echo "  ├─────────────────────────────────────────────┤"
printf "  │  %-20s %-22s│\n" "Usuario IPFS:" "$user_name"
printf "  │  %-20s %-22s│\n" "Dominio SSL:" "$DOMAIN"
printf "  │  %-20s %-22s│\n" "Método:" "Edición Offline (Evita Bloqueo RPC)"
echo -e "  └─────────────────────────────────────────────┘${NC}\n"

if ! confirm "¿Deseas aplicar esta configuración?"; then
    exit 0
fi

# =============================================================================
#  3. APLICACIÓN CON PARADA PREVIA (Soluciona Access Denied)
# =============================================================================
banner "Aplicando Configuración"

rollback() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        warn "¡Error detectado! Revirtiendo cambios..."
        [ -f "${CONFIG_PATH}.bak" ] && sudo cp "${CONFIG_PATH}.bak" "$CONFIG_PATH"
        [ -f "/etc/caddy/Caddyfile.bak" ] && sudo cp "/etc/caddy/Caddyfile.bak" "/etc/caddy/Caddyfile"
        sudo chown "$user_name:$user_name" "$CONFIG_PATH" || true
    fi
    exit $exit_code
}
trap rollback ERR

# --- Backups y Parada de Seguridad ---
info "Creando backups y deteniendo servicios para edición..."
sudo cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"
[[ -f /etc/caddy/Caddyfile ]] && sudo cp /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.bak"

# Detenemos IPFS para poder editar el config sin que el RPC nos bloquee
if systemctl is-active --quiet ipfs; then
    sudo systemctl stop ipfs
    sleep 1
fi

# --- Edición con JQ (Offline) ---
info "Limpiando API y configurando Gateway/Swarm vía JQ..."

# Realizamos todos los cambios en un solo paso de JQ
sudo jq --arg domain "https://$DOMAIN" '
    .API = {"HTTPHeaders": {}} |
    .Addresses.Gateway = "/ip4/127.0.0.1/tcp/8080" |
    .Addresses.Swarm = ["/ip4/0.0.0.0/tcp/4001", "/ip4/0.0.0.0/tcp/8081/ws", "/ip6/::/tcp/4001"]
' "$CONFIG_PATH" > "${CONFIG_PATH}.tmp"

sudo mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"
sudo chown "$user_name:$user_name" "$CONFIG_PATH"

# --- Configuración Caddyfile ---
info "Actualizando Caddyfile..."
CADDY_CONTENT=$(cat <<EOF
# 1. Swarm WebSocket con SSL
$DOMAIN:4002 {
    reverse_proxy localhost:8081
}

# 2. Gateway Público con SSL
$DOMAIN {
    reverse_proxy localhost:8080 {
        header_up Host {host}
    }
}
EOF
)
echo "$CADDY_CONTENT" | sudo tee /etc/caddy/Caddyfile > /dev/null

# =============================================================================
#  4. REINICIO Y VERIFICACIÓN
# =============================================================================
banner "Reiniciando Servicios"

info "Iniciando IPFS..."
sudo systemctl daemon-reload
sudo systemctl start ipfs

info "Reiniciando Caddy..."
sudo systemctl restart caddy

# Verificación de salud
sleep 2
if systemctl is-active --quiet ipfs && systemctl is-active --quiet caddy; then
    banner "¡Configuración Exitosa!"
    info "Gateway SSL activo: ${CYAN}https://$DOMAIN${NC}"
    info "Swarm WS activo: ${CYAN}wss://$DOMAIN:4002${NC}"
    echo ""
    info "Visita: https://${CYAN}$DOMAIN${NC}/ipfs/bafkreig24ijzqxj3cxdp6yh6ia2ysxzvxsfnd6rzahxxjv6ofcuix52wtq"
    info "Si ves el logo de IPFS, el Gateway fue configurado correctamente."
    echo ""
else
    warn "Los servicios se configuraron pero alguno no pudo arrancar."
    warn "Revisa: journalctl -xeu ipfs"
fi