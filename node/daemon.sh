#!/bin/bash

# =============================================================================
#  IPFS Daemon & Service Configuration Script (User Detection Fix)
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

# --- Variables de Contexto (MEJORADO) ---
# 1. Buscamos IPFS_USER (pasada por main)
# 2. Si no existe, buscamos SUDO_USER (el usuario que ejecutó el sudo)
# 3. Como último recurso, el USER actual (probablemente root)
user_name="${IPFS_USER:-${SUDO_USER:-$USER}}"
USER_HOME=$(getent passwd "$user_name" | cut -d: -f6)
IPFS_PATH="${USER_HOME}/.ipfs"
IPFS_BIN=$(which ipfs || echo "/usr/local/bin/ipfs")

# =============================================================================
#  1. ANÁLISIS DEL SISTEMA
# =============================================================================
banner "Análisis del Sistema"

INIT_SYSTEM="unknown"
SERVICE_FILE=""

if [[ -d /run/systemd/system ]] || systemctl is-system-running &>/dev/null 2>&1; then
    INIT_SYSTEM="systemd"
    SERVICE_FILE="/etc/systemd/system/ipfs.service"
elif [[ -f /sbin/openrc ]] || command -v rc-service &>/dev/null; then
    INIT_SYSTEM="openrc"
    SERVICE_FILE="/etc/init.d/ipfs"
fi

info "Sistema de Init detectado: ${CYAN}${INIT_SYSTEM}${NC}"

CURRENT_GC="Inactivo"
STATUS="No instalado"
ENABLED="No"

if [[ -f "$SERVICE_FILE" ]]; then
    if grep -q "\-\-enable-gc" "$SERVICE_FILE"; then CURRENT_GC="Activo"; fi
    
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        [[ $(systemctl is-active ipfs.service 2>/dev/null) == "active" ]] && STATUS="Corriendo" || STATUS="Detenido"
        [[ $(systemctl is-enabled ipfs.service 2>/dev/null) == "enabled" ]] && ENABLED="SÍ" || ENABLED="NO"
    elif [[ "$INIT_SYSTEM" == "openrc" ]]; then
        rc-service ipfs status &>/dev/null && STATUS="Corriendo" || STATUS="Detenido"
        rc-update show default | grep -q "ipfs" && ENABLED="SÍ" || ENABLED="NO"
    fi
fi

echo -e "  - Servicio:         ${CYAN}$SERVICE_FILE${NC}"
echo -e "  - Estado actual:    $([[ "$STATUS" == "Corriendo" ]] && echo -e "${GREEN}$STATUS${NC}" || echo -e "${RED}$STATUS${NC}")"
echo -e "  - Autoarranque:     $([[ "$ENABLED" == "SÍ" ]] && echo -e "${GREEN}$ENABLED${NC}" || echo -e "${RED}$ENABLED${NC}")"
echo -e "  - Garbage Collector: $([[ "$CURRENT_GC" == "Activo" ]] && echo -e "${GREEN}$CURRENT_GC${NC}" || echo -e "${RED}$CURRENT_GC${NC}")"

if [[ "$STATUS" != "No instalado" ]]; then
    echo ""
    if ! confirm "El servicio ya existe. ¿Deseas reconfigurarlo?"; then
        exit 0
    fi
fi

# =============================================================================
#  2. CONFIGURACIÓN DEL NODO
# =============================================================================
banner "Configuración del Nodo"

if confirm "¿Deseas activar el Garbage Collector?"; then
    GC_FLAG="--enable-gc"
    GC_STATUS="Activado"
else
    GC_FLAG=""
    GC_STATUS="Desactivado"
fi

AUTO_START="n"
if confirm "¿Deseas que IPFS se inicie automáticamente al arrancar?"; then
    AUTO_START="y"
fi

# =============================================================================
#  3. RESUMEN Y CONFIRMACIÓN FINAL
# =============================================================================
echo -e "\n  ${CYAN}┌─────────────────────────────────────────────┐"
printf "  │  %-43s│\n" "RESUMEN DE CONFIGURACIÓN"
echo "  ├─────────────────────────────────────────────┤"
printf "  │  %-20s %-22s│\n" "Usuario:" "$user_name"
printf "  │  %-20s %-22s│\n" "Ruta IPFS:" "$IPFS_PATH"
printf "  │  %-20s %-22s│\n" "Init System:" "$INIT_SYSTEM"
printf "  │  %-20s %-22s│\n" "Autoarranque:" "$([[ "$AUTO_START" == "y" ]] && echo "SÍ" || echo "NO")"
printf "  │  %-20s %-22s│\n" "G. Collector:" "$GC_STATUS"
echo -e "  └─────────────────────────────────────────────┘${NC}\n"

if ! confirm "¿Aplicar estos cambios en el sistema?"; then
    warn "Operación cancelada."
    exit 0
fi

# =============================================================================
#  4. APLICACIÓN Y ROLLBACK
# =============================================================================
banner "Aplicando cambios"

rollback() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        warn "¡Algo salió mal! Restaurando estado anterior..."
        if [[ -f "${SERVICE_FILE}.bak" ]]; then
            sudo mv "${SERVICE_FILE}.bak" "$SERVICE_FILE"
        fi
        [[ "$INIT_SYSTEM" == "systemd" ]] && sudo systemctl daemon-reload && sudo systemctl start ipfs.service || true
    fi
    exit $exit_code
}
trap rollback ERR

if [[ -f "$SERVICE_FILE" ]]; then
    info "Creando backup..."
    sudo cp "$SERVICE_FILE" "${SERVICE_FILE}.bak"
    info "Deteniendo servicio para liberar bloqueos..."
    sudo systemctl stop ipfs.service || true
    sleep 2
fi

# Escribir Configuración
if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=IPFS Kubo Daemon
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=${user_name}
Group=${user_name}
Environment=IPFS_PATH=${IPFS_PATH}
ExecStart=${IPFS_BIN} daemon ${GC_FLAG}
Restart=on-failure
RestartSec=5s
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    info "Reiniciando servicio..."
    sudo systemctl start ipfs.service
    
    if [[ "$AUTO_START" == "y" ]]; then
        sudo systemctl enable ipfs.service
    else
        sudo systemctl disable ipfs.service 2>/dev/null || true
    fi
fi

# =============================================================================
#  5. VERIFICACIÓN FINAL
# =============================================================================
banner "¡Configuración Exitosa!"
if systemctl is-active --quiet ipfs.service; then
    info "El servicio está corriendo correctamente como usuario: ${YELLOW}$user_name${NC}"
    sudo systemctl status ipfs.service --no-pager | grep -E "Active:|Main PID:"
else
    warn "El servicio falló al arrancar. Es posible que el repositorio pertenezca a otro usuario."
    warn "Intenta corregir permisos con: sudo chown -R $user_name:$user_name $IPFS_PATH"
    exit 1
fi