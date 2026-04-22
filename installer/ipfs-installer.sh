#!/bin/bash
# =============================================================================
#  IPFS (Kubo) Auto-Installer — Debian/Ubuntu y derivadas
#  Based on: AndyDevla/ipfs-auto-installer
#  Soportado: Debian, Ubuntu, Linux Mint, Pop!_OS, Zorin, Raspbian y derivadas
#  Gestor de paquetes requerido: APT
# =============================================================================

set -euo pipefail

# =============================================================================
#  COLORES
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;97m'
NC='\033[0m'

# =============================================================================
#  FUNCIONES UTILITARIAS
# =============================================================================

banner() {
    echo ""
    echo -e "${CYAN}          ╔══════════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}          ║  %-62s║${NC}\n" "$1"
    echo -e "${CYAN}          ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
confirm() { local _r; read -p "$(echo -e "${YELLOW}[?]${NC} $1 [s/N]: ")" _r; [[ "${_r,,}" == "s" ]]; }

# =============================================================================
#  SISTEMA DE ROLLBACK
#  Registro de todo lo que se crea/modifica para poder revertirlo
# =============================================================================

ROLLBACK_ACTIONS=()

register_rollback() {
    ROLLBACK_ACTIONS+=("$1|$2")
}

do_rollback() {
    echo ""
    echo -e "${RED}          ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}          ║  Revirtiendo instalación...                                  ║${NC}"
    echo -e "${RED}          ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ "${#ROLLBACK_ACTIONS[@]}" -eq 0 ]]; then
        warn "No hay acciones que revertir."
        return
    fi

    local total="${#ROLLBACK_ACTIONS[@]}"
    for (( i=total-1; i>=0; i-- )); do
        local entry="${ROLLBACK_ACTIONS[$i]}"
        local desc="${entry%%|*}"
        local cmd="${entry##*|}"
        echo -e "  ${YELLOW}↩${NC}  $desc"
        eval "$cmd" 2>/dev/null || warn "No se pudo revertir: $desc"
    done

    echo ""
    warn "Rollback completado. Revisa el log para más detalles: $LOG_FILE"
    echo ""
}

backup_if_exists() {
    local target="$1"
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    if [[ -f "$target" ]]; then
        cp "$target" "${target}.bak-${ts}"
        info "Backup creado: ${target}.bak-${ts}"
    elif [[ -d "$target" ]]; then
        cp -r "$target" "${target}.bak-${ts}"
        info "Backup creado: ${target}.bak-${ts}"
    fi
}

INSTALL_SUCCESSFUL=false
_on_exit() {
    _cleanup_tmpdir
    if [[ "$INSTALL_SUCCESSFUL" == false ]]; then
        do_rollback
    fi
}

TMPDIR=""
_cleanup_tmpdir() {
    [[ -n "$TMPDIR" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR"
}

trap '_on_exit' EXIT
trap 'echo ""; echo "❌  Error en línea $LINENO. Iniciando rollback..."; exit 1' ERR

# =============================================================================
#  1. VERIFICAR QUE SE EJECUTA COMO ROOT
# =============================================================================
if [[ "$EUID" -ne 0 ]]; then
    error "Este script debe ejecutarse con sudo o como root."
    echo "  Uso: sudo bash ipfs-installer.sh"
    INSTALL_SUCCESSFUL=true
    exit 1
fi

# =============================================================================
#  1b. VERIFICAR DISTRO COMPATIBLE (APT)
# =============================================================================
if [[ ! -f /etc/os-release ]]; then
    error "No se puede detectar el sistema operativo (/etc/os-release no existe)."
    INSTALL_SUCCESSFUL=true
    exit 1
fi

OS_ID=$(grep -w "^ID" /etc/os-release | cut -d= -f2 | tr -d '"' || echo "unknown")
OS_ID_LIKE=$(grep -w "^ID_LIKE" /etc/os-release | cut -d= -f2 | tr -d '"' || echo "")
OS_CODENAME=$(grep -w "^VERSION_CODENAME" /etc/os-release | cut -d= -f2 | tr -d '"' || echo "")

case "$OS_ID" in
    linuxmint|pop|zorin|neon|elementary|parrot|kali) OS_ID="ubuntu" ;;
    raspbian)                                         OS_ID="debian" ;;
esac

if [[ "$OS_ID" != "debian" && "$OS_ID" != "ubuntu" ]]; then
    if echo "$OS_ID_LIKE" | grep -qE "(debian|ubuntu)"; then
        info "Derivada detectada (ID_LIKE): compatible con APT."
    else
        error "Sistema no soportado: $OS_ID"
        echo "  Este script solo funciona en Debian, Ubuntu y sus derivadas (APT)."
        echo "  Soporte para otras distros se añadirá en versiones futuras."
        INSTALL_SUCCESSFUL=true
        exit 1
    fi
fi

if ! command -v apt-get &>/dev/null; then
    error "No se encontró apt-get. Este script requiere un sistema basado en APT."
    INSTALL_SUCCESSFUL=true
    exit 1
fi

info "Sistema compatible: $OS_ID ${OS_CODENAME:+(${OS_CODENAME})} ✔"

# =============================================================================
#  1c. LOGGING DUAL (stdout + archivo)
# =============================================================================
LOG_FILE="/tmp/ipfs-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
info "Log de instalación guardado en: $LOG_FILE"

# =============================================================================
#  2. VERIFICAR DEPENDENCIAS
# =============================================================================
banner "Verificando dependencias"

MISSING=()
for cmd in tar curl; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$cmd")
    else
        info "$cmd ✔"
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    error "Faltan las siguientes herramientas: ${MISSING[*]}"
    echo "  Instálalas con:"
    echo "    sudo apt-get install -y ${MISSING[*]}"
    INSTALL_SUCCESSFUL=true
    exit 1
fi

# =============================================================================
#  3. DETECTAR ARQUITECTURA
# =============================================================================
banner "Detectando arquitectura del sistema"

ARCH=$(uname -m)
case $ARCH in
    x86_64)        ARCH_IPFS="amd64"   ;;
    aarch64|arm64) ARCH_IPFS="arm64"   ;;
    riscv64)       ARCH_IPFS="riscv64" ;;
    armv7l|armv6l)
        error "Arquitectura ARM 32-bit ($ARCH) no está soportada por Kubo."
        echo "  Kubo solo publica builds para: amd64, arm64, riscv64."
        echo "  Considera compilar desde el código fuente: https://github.com/ipfs/kubo"
        INSTALL_SUCCESSFUL=true
        exit 1
        ;;
    *)
        error "Arquitectura no soportada: $ARCH"
        echo "  Kubo solo publica builds para: amd64, arm64, riscv64."
        INSTALL_SUCCESSFUL=true
        exit 1
        ;;
esac
info "Arquitectura detectada: $ARCH → kubo build: linux-${ARCH_IPFS}"

# =============================================================================
#  4. VERIFICAR INSTALACIÓN EXISTENTE Y SELECCIÓN DE VERSIÓN
# =============================================================================
SELECTED_VERSION=""

if command -v ipfs &>/dev/null; then
    info "Comprobando actualizaciones..."
    
    LOCAL_RAW=$(ipfs --version | cut -d' ' -f3)
    LOCAL_VER="${LOCAL_RAW#v}"
    
    # Obtenemos la lista de versiones estables (sin 'rc') y las invertimos para ver las más nuevas arriba
    STABLE_VERSIONS=($(curl -s https://dist.ipfs.tech/kubo/versions | grep -v 'rc' | tac))
    LATEST_REMOTE="${STABLE_VERSIONS[0]}"
    REMOTE_VER="${LATEST_REMOTE#v}"

    warn "IPFS ya está instalado (Versión actual: ${YELLOW}${LOCAL_RAW}${NC})"
    
    if [[ "$LOCAL_VER" == "$REMOTE_VER" ]]; then
        info "Ya tienes la versión más reciente instalada."
        echo ""
        if ! confirm "¿Deseas reinstalar IPFS de todos modos?"; then
            INSTALL_SUCCESSFUL=true
            exit 0
        fi
    fi

    # Menú de selección de versión
    echo ""
    info "Selecciona la versión que deseas instalar:"
    echo "1) La misma versión instalada (${LOCAL_RAW})"
    echo "2) La última versión estable (${LATEST_REMOTE})"
    echo "3) Elegir de una lista de versiones anteriores"
    echo "4) Cancelar"
    echo ""
    read -p "Selecciona una opción [1-4]: " v_opt

    case $v_opt in
        1) SELECTED_VERSION="$LOCAL_RAW" ;;
        2) SELECTED_VERSION="$LATEST_REMOTE" ;;
        3)
            echo ""
            echo -e "${CYAN}Versiones estables disponibles (últimas 15):${NC}"
            # Tomamos las últimas 15 versiones para no inundar la pantalla
            PS3=$(echo -e "\n${YELLOW}[?] Elige el número de versión: ${NC}")
            select opt in "${STABLE_VERSIONS[@]:0:15}"; do
                if [[ -n "$opt" ]]; then
                    SELECTED_VERSION="$opt"
                    break
                else
                    error "Opción inválida."
                fi
            done
            ;;
        *) 
            info "Operación cancelada por el usuario."
            INSTALL_SUCCESSFUL=true
            exit 0 
            ;;
    esac
else
    # Si no está instalado, por defecto buscamos la última
    SELECTED_VERSION=$(curl -s https://dist.ipfs.tech/kubo/versions | grep -v 'rc' | tail -n 1)
fi

# Exportamos la versión elegida para que la sección 6 la use
LATEST_REMOTE="$SELECTED_VERSION"
info "Versión seleccionada para instalar: ${GREEN}${LATEST_REMOTE}${NC}"

# =============================================================================
#  5. RECOGER INPUTS DEL USUARIO
# =============================================================================
banner "Configuración de la instalación"

# --- Usuario ---
DEFAULT_USER="${SUDO_USER:-$USER}"
read -p "Introduce el usuario que ejecutará IPFS [$DEFAULT_USER]: " user_name
user_name="${user_name:-$DEFAULT_USER}"

if ! id "$user_name" &>/dev/null; then
    error "El usuario '$user_name' no existe en el sistema."
    INSTALL_SUCCESSFUL=true
    exit 1
fi

USER_HOME=$(getent passwd "$user_name" | cut -d: -f6)
echo ""
info "Home del usuario: $USER_HOME"

if [[ -d "${USER_HOME}/.ipfs" ]]; then
    warn "Se encontró un repositorio IPFS existente en ${USER_HOME}/.ipfs"
    warn "La reinstalación NO borrará los datos existentes."
fi
echo ""

# =============================================================================
#  5b. CONFIRMACIÓN PREVIA
# =============================================================================
echo ""
echo "  ┌─────────────────────────────────────────────┐"
printf "  │  %-44s│\n" "Resumen de la instalación"
echo "  ├─────────────────────────────────────────────┤"
printf "  │  %-20s %-23s│\n" "Usuario:"        "$user_name"
printf "  │  %-20s %-23s│\n" "Versión:"        "$LATEST_REMOTE"
printf "  │  %-20s %-23s│\n" "Home:"           "$USER_HOME"
printf "  │  %-20s %-23s│\n" "Arquitectura:"   "linux-${ARCH_IPFS}"
echo "  └─────────────────────────────────────────────┘"
echo ""

if ! confirm "¿Confirmas la instalación con estos parámetros?"; then
    info "Instalación cancelada por el usuario."
    INSTALL_SUCCESSFUL=true
    exit 0
fi
echo ""

# =============================================================================
#  A PARTIR DE AQUÍ EL ROLLBACK ESTÁ ACTIVO
# =============================================================================

# =============================================================================
#  6. DESCARGAR KUBO
# =============================================================================
banner "Descargando IPFS (Kubo)"

# Aseguramos que la versión tenga el prefijo 'v' para la URL de descarga
if [[ ! "$LATEST_REMOTE" =~ ^v ]]; then
    DOWNLOAD_VER="v$LATEST_REMOTE"
else
    DOWNLOAD_VER="$LATEST_REMOTE"
fi

TMPDIR=$(mktemp -d)
cd "$TMPDIR"

TARBALL="kubo_${DOWNLOAD_VER}_linux-${ARCH_IPFS}.tar.gz"
URL="https://dist.ipfs.tech/kubo/${DOWNLOAD_VER}/${TARBALL}"

info "Descargando: $TARBALL"
# Usamos curl con: 
# -L (seguir redirecciones)
# -# (barra de progreso simple)
# -o (archivo de salida)
if ! curl -L -# "$URL" -o "$TARBALL"; then
    error "No se pudo descargar el archivo. Verifica tu conexión o la versión."
    exit 1
fi

# --- Verificar checksum SHA512 con curl ---
info "Verificando checksum SHA512..."
if ! curl -sL "${URL}.sha512" -o "${TARBALL}.sha512"; then
    warn "No se pudo descargar el checksum, omitiendo verificación."
else
    if command -v sha512sum &>/dev/null; then
        # IPFS entrega el checksum en un formato que a veces requiere limpieza
        if sha512sum -c "${TARBALL}.sha512" &>/dev/null; then
            info "Checksum OK ✔"
        else
            error "Checksum inválido. Archivo corrupto."
            exit 1
        fi
    else
        warn "sha512sum no disponible, omitiendo verificación."
    fi
fi

# =============================================================================
#  7. INSTALAR KUBO
# =============================================================================
banner "Instalando IPFS"

tar -xzf "$TARBALL"
cd kubo
bash install.sh
cd "$TMPDIR"

IPFS_BIN=$(command -v ipfs 2>/dev/null || echo "/usr/local/bin/ipfs")
register_rollback "Eliminar binario ipfs ($IPFS_BIN)" "rm -f '${IPFS_BIN}'"

IPFS_VERSION=$(ipfs --version 2>/dev/null || true)
if [[ -z "$IPFS_VERSION" ]]; then
    error "La instalación de IPFS falló o no está en el PATH."
    exit 1
fi
info "Instalado: $IPFS_VERSION"

#sudo -u "$user_name" bash -c \
#    "ipfs id | head -n 3 | tail -n 2 > \"${USER_HOME}/IPFS_identity.txt\""
#register_rollback "Eliminar ${USER_HOME}/IPFS_identity.txt" "rm -f '${USER_HOME}/IPFS_identity.txt'"
#info "Identidad guardada en ${USER_HOME}/IPFS_identity.txt"

# =============================================================================
#  8. RESUMEN FINAL
# =============================================================================
banner "Instalación completada"

echo -e "  ${GREEN}Usuario:${NC}        $user_name"
echo -e "  ${GREEN}Versión:${NC}        $IPFS_VERSION"
echo -e "  ${GREEN}Arquitectura:${NC}   linux-${ARCH_IPFS}"
#echo -e "  ${GREEN}Identidad:${NC}      ${USER_HOME}/IPFS_identity.txt"
echo -e "  ${GREEN}Log:${NC}            $LOG_FILE"
echo ""

INSTALL_SUCCESSFUL=true