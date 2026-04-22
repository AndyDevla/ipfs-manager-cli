#!/bin/bash
# =============================================================================
#  IPFS (Kubo) Uninstaller — Seguro, Agnóstico y Bajo Confirmación
# =============================================================================

set -euo pipefail

# --- Colores y Estética ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Funciones de Utilidad ---
banner() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════╗"
    printf "║  %-60s║\n" "$1"
    echo -e "╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
removed() { echo -e "${RED}[ELIMINADO]${NC} $1"; }

confirm_keyword() {
    local _r
    read -p "$(echo -e "${YELLOW}[?]${NC} ¿Confirmas la desinstalación total? [Escribe 'SÍ' para proceder]: ")" _r
    [[ "$_r" == "SÍ" ]]
}

# =============================================================================
#  1. PRE-REQUISITOS Y DETECCIÓN
# =============================================================================
if [[ "$EUID" -ne 0 ]]; then
    error "Este script debe ejecutarse con sudo o como root."
    exit 1
fi

LOG_FILE="/tmp/ipfs-uninstall-$(date +%Y%m%d-%H%M).log"
exec > >(tee -a "$LOG_FILE") 2>&1

banner "Fase de Configuración: Desinstalador IPFS"

# Detectar Usuario
DEFAULT_USER="${SUDO_USER:-$USER}"
read -p "$(echo -e "${CYAN}[>]${NC} Usuario que gestionaba IPFS [$DEFAULT_USER]: ")" user_name
user_name="${user_name:-$DEFAULT_USER}"

USER_HOME=$(getent passwd "$user_name" | cut -d: -f6 || echo "")
if [[ -z "$USER_HOME" ]]; then
    error "No se pudo encontrar el home del usuario '$user_name'."
    exit 1
fi

# Detectar Sistema de Init
INIT_SYSTEM="Desconocido"
if [[ -d /run/systemd/system ]]; then INIT_SYSTEM="systemd";
elif [[ -f /sbin/openrc ]]; then INIT_SYSTEM="openrc";
elif command -v sv &>/dev/null; then INIT_SYSTEM="runit"; fi

# =============================================================================
#  2. PREGUNTAS (Antes de aplicar cambios)
# =============================================================================

# Pregunta: Repositorio
DEL_REPO="n"
IPFS_REPO="${USER_HOME}/.ipfs"
if [[ -d "$IPFS_REPO" ]]; then
    echo -e "\n${YELLOW}[!] Se detectó un repositorio en: $IPFS_REPO ($(du -sh "$IPFS_REPO" 2>/dev/null | cut -f1))${NC}"
    read -p "$(echo -e "${CYAN}[?]${NC} ¿Deseas eliminar el REPOSITORIO y todos tus datos (CIDs/Keys)? [s/N]: ")" DEL_REPO
fi

# Pregunta: Servicio
DEL_SERVICE="n"
HAS_SERVICE=false
case "$INIT_SYSTEM" in
    systemd) [[ -f /etc/systemd/system/ipfs.service ]] && HAS_SERVICE=true ;;
    openrc)  [[ -f /etc/init.d/ipfs ]] && HAS_SERVICE=true ;;
    runit)   [[ -d /etc/sv/ipfs ]] && HAS_SERVICE=true ;;
esac

if [ "$HAS_SERVICE" = true ]; then
    echo -e "${YELLOW}[!] Se detectó un archivo de servicio para IPFS ($INIT_SYSTEM).${NC}"
    read -p "$(echo -e "${CYAN}[?]${NC} ¿Deseas eliminar el SERVICIO del sistema? [s/N]: ")" DEL_SERVICE
fi

# =============================================================================
#  3. RESUMEN Y CONFIRMACIÓN FINAL
# =============================================================================
echo -e "\n${BOLD}RESUMEN DE ACCIONES:${NC}"
echo -e "  - Se detendrá cualquier proceso IPFS en ejecución."
echo -e "  - Se eliminará el binario: $(command -v ipfs || echo 'No encontrado')"
[[ "${DEL_REPO,,}" == "s" ]] && echo -e "  - ${RED}BORRADO CRÍTICO:${NC} Se eliminará el repositorio en $IPFS_REPO" || echo "  - El repositorio se mantendrá intacto."
[[ "${DEL_SERVICE,,}" == "s" ]] && echo -e "  - Se eliminarán los archivos de servicio ($INIT_SYSTEM)." || echo "  - Los archivos de servicio se mantendrán."
echo ""

if ! confirm_keyword; then
    warn "Desinstalación abortada. No se realizaron cambios."
    exit 0
fi

# =============================================================================
#  4. EJECUCIÓN (A partir de aquí se aplican cambios)
# =============================================================================
banner "Ejecutando Desinstalación"

# A. Detener procesos (Automático e Idempotente)
info "Deteniendo procesos y servicios de IPFS..."
if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    systemctl stop ipfs 2>/dev/null || true
    systemctl disable ipfs 2>/dev/null || true
elif [[ "$INIT_SYSTEM" == "openrc" ]]; then
    rc-service ipfs stop 2>/dev/null || true
fi
pkill -9 -x ipfs 2>/dev/null || true
info "Procesos detenidos."

# B. Eliminar Servicio (Si se confirmó)
if [[ "${DEL_SERVICE,,}" == "s" ]]; then
    case "$INIT_SYSTEM" in
        systemd)
            rm -f /etc/systemd/system/ipfs.service
            systemctl daemon-reload
            removed "Archivo de servicio systemd"
            ;;
        openrc)
            rm -f /etc/init.d/ipfs
            removed "Script de inicio OpenRC"
            ;;
        runit)
            rm -rf /etc/sv/ipfs /var/service/ipfs
            removed "Directorio de servicio Runit"
            ;;
    esac
fi

# C. Eliminar Binario
IPFS_PATH=$(command -v ipfs || echo "/usr/local/bin/ipfs")
if [[ -f "$IPFS_PATH" ]]; then
    rm -f "$IPFS_PATH"
    removed "Binario: $IPFS_PATH"
fi

# D. Eliminar Repositorio (Si se confirmó)
if [[ "${DEL_REPO,,}" == "s" ]]; then
    if [[ -d "$IPFS_REPO" ]]; then
        rm -rf "$IPFS_REPO"
        removed "Repositorio de datos: $IPFS_REPO"
    fi
fi

# =============================================================================
#  5. VERIFICACIÓN Y CIERRE
# =============================================================================
banner "Proceso Finalizado"

if ! command -v ipfs &>/dev/null; then
    info "IPFS (Kubo) ha sido removido exitosamente."
else
    warn "El binario todavía parece estar presente. Verifica manualmente."
fi

info "Log detallado en: $LOG_FILE"
echo ""