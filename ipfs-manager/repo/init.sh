#!/bin/bash

# =============================================================================
#  IPFS Repository Init Script - Optimizado
# =============================================================================

set -euo pipefail

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;97m'
NC='\033[0m'

# --- Funciones ---
banner() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════╗"
    printf "║  %-60s║\n" "$1"
    echo -e "╚══════════════════════════════════════════════════════════════╝${NC}\n"
}
info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
confirm() { local _r; read -p "$(echo -e "${YELLOW}[?]${NC} $1 [s/N]: ")" _r; [[ "${_r,,}" == "s" ]]; }

# --- Recuperar contexto del Master Script ---
user_name="${IPFS_USER:-$USER}"
USER_HOME=$(getent passwd "$user_name" | cut -d: -f6)
# Usamos el comando exportado, o uno local por defecto si se corre solo
EXEC_IPFS="${IPFS_CMD:-ipfs}"

banner "Configuración Inicial de Repositorio"

# =============================================================================
#  1. PERFIL DE SERVIDOR (AHORA PRIMERO)
# =============================================================================
info "Paso 1: Definir perfil de uso"
echo -e "El perfil ${CYAN}'server'${NC} desactiva el descubrimiento local (mDNS) para ahorrar ancho de banda en la nube."
read -p "$(echo -e "${YELLOW}[?]${NC} ¿Deseas aplicar el perfil de servidor? [y/n]: ")" s_prof
echo ""

# =============================================================================
#  2. ALMACENAMIENTO (MENÚ NUMERADO)
# =============================================================================
info "Paso 2: Capacidad de almacenamiento"
DISK_INFO=$(df -BG "$USER_HOME" | awk 'NR==2 {print $4}')
DISK_AVAIL=$(echo "$DISK_INFO" | tr -d 'G')

echo -e "Espacio disponible: ${GREEN}${DISK_AVAIL}GB${NC}"
percentages=(10 25 50 60 80 95)

for i in "${!percentages[@]}"; do
    p="${percentages[$i]}"
    val=$(( DISK_AVAIL * p / 100 ))
    [[ $val -eq 0 ]] && val=1
    echo -e "  $((i+1))) ${p}% (~${val} GB)"
done
echo -e "  7) Cantidad personalizada"
echo ""

while true; do
    read -p "  Selecciona una opción [1-7]: " opt
    case $opt in
        [1-6])
            max_storage=$(( DISK_AVAIL * ${percentages[$((opt-1))]} / 100 ))
            [[ $max_storage -eq 0 ]] && max_storage=1
            break ;;
        7)
            read -p "  Ingresa GB: " max_storage
            [[ "$max_storage" =~ ^[0-9]+$ ]] && break || echo "Número inválido." ;;
        *) echo "Opción inválida." ;;
    esac
done

# =============================================================================
#  3. CONFIRMACIÓN Y EJECUCIÓN
# =============================================================================
echo -e "\n${CYAN}Resumen:${NC}"
echo "  - Usuario: $user_name"
echo "  - Perfil Server: $([[ "$s_prof" == "y" ]] && echo "SÍ" || echo "NO")"
echo "  - Capacidad: ${max_storage}GB"
echo ""

if ! confirm "¿Aplicar configuración inicial?"; then
    info "Cancelado."
    exit 0
fi

# Ejecución de comandos usando la variable global
IPFS_REPO="${USER_HOME}/.ipfs"

if [[ ! -d "$IPFS_REPO" ]]; then
    info "Inicializando repositorio..."
    if [[ "$s_prof" == "y" ]]; then
        $EXEC_IPFS init --profile server
    else
        $EXEC_IPFS init
    fi
else
    warn "El repositorio ya existe en $IPFS_REPO. Saltando init."
fi

info "Estableciendo límite de almacenamiento..."
$EXEC_IPFS config Datastore.StorageMax "${max_storage}GB"

banner "¡Repositorio Configurado!"