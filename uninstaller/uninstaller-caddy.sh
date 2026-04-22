#!/bin/bash

# =============================================================================
#  IPFS Gateway - Caddy Uninstaller (Agnostic & Safe)
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
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Confirmación robusta
confirm_final() {
    local _r
    echo -e "\n${RED}⚠️  ¡ATENCIÓN! Esta acción no se puede deshacer.${NC}"
    read -p "$(echo -e "${YELLOW}[?]${NC} ¿Estás seguro de que deseas proceder? [escribe 'SÍ' para confirmar]: ")" _r
    [[ "$_r" == "SÍ" ]]
}

# =============================================================================
#  1. VERIFICACIÓN INICIAL
# =============================================================================
banner "Análisis de Desinstalación"

if ! command -v caddy &>/dev/null; then
    warn "Caddy no está detectado en el sistema."
    echo -e "Si deseas instalarlo, usa la ${CYAN}Opción 4 -> Subopción 1${NC} del menú."
    exit 0
fi

info "Caddy detectado: $(caddy version | awk '{print $1}')"

# =============================================================================
#  2. SELECCIÓN DE MODO
# =============================================================================
echo -e "\n${CYAN}Selecciona el nivel de desinstalación:${NC}"
echo "1) Estándar: Quita el binario. Mantiene Caddyfile y Certificados SSL."
echo "2) Completa (PURGA): Borra binarios, SSL, Logs y Repositorios."
echo "0) Cancelar"
echo ""
read -p "Opción: " opt

case $opt in
    1)
        MODE="ESTÁNDAR"
        RESUMEN="Se eliminará el binario de Caddy pero se conservará la configuración."
        ;;
    2)
        MODE="PURGA"
        RESUMEN="Se eliminará Caddy, certificados SSL, logs y repositorios del sistema."
        ;;
    *)
        info "Operación cancelada por el usuario."
        exit 0
        ;;
esac

# EXIGIR CONFIRMACIÓN ANTES DE TOCAR NADA
echo -e "\nModo seleccionado: ${YELLOW}$MODE${NC}"
info "$RESUMEN"

if ! confirm_final; then
    warn "Desinstalación abortada. No se han realizado cambios."
    exit 0
fi

# =============================================================================
#  3. DETENCIÓN (Systemd o Process Kill)
# =============================================================================
banner "Paso 1: Deteniendo Servicios"

if [[ -d /run/systemd/system ]]; then
    info "Usando systemctl para detener Caddy..."
    sudo systemctl stop caddy || true
    sudo systemctl disable caddy &>/dev/null || true
else
    info "Systemd no detectado. Terminando procesos de Caddy..."
    sudo pkill -f caddy || warn "No había procesos activos."
fi

# =============================================================================
#  4. EJECUCIÓN DE LIMPIEZA
# =============================================================================
banner "Paso 2: Eliminando Paquetes"

if [[ "$MODE" == "PURGA" ]]; then
    sudo apt purge -y caddy
    sudo apt autoremove -y
    
    info "Limpiando archivos de datos y SSL..."
    sudo rm -rf /var/lib/caddy
    sudo rm -rf /etc/caddy
    sudo rm -rf /var/log/caddy
    
    info "Eliminando llaves y repositorios..."
    sudo rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    sudo rm -f /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update &>/dev/null
else
    sudo apt remove -y caddy
    warn "Configuración en /etc/caddy preservada."
fi

# =============================================================================
#  5. VERIFICACIÓN FINAL
# =============================================================================
echo ""
if ! command -v caddy &>/dev/null; then
    banner "¡Desinstalación Exitosa!"
    info "Caddy ha sido removido del sistema."
else
    error "Algo falló. El binario de Caddy aún responde."
fi

echo -e "\nPresiona Enter para volver..."
read