#!/bin/bash

# =============================================================================
#  IPFS Secure Gateway Path + RPC - Universal & Robust Rollback (Option 4 -> Sub 4)
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

# --- Detección de Sistema de Inicio ---
if [[ -d /run/systemd/system ]]; then
    INIT_SYSTEM="systemd"
else
    INIT_SYSTEM="manual"
fi

# --- Variables de Contexto ---
user_name="${IPFS_USER:-${SUDO_USER:-$USER}}"
USER_HOME=$(getent passwd "$user_name" | cut -d: -f6)
IPFS_PATH="${USER_HOME}/.ipfs"
CONFIG_PATH="$IPFS_PATH/config"
DATE=$(date +"%Y%m%d-%H%M")

# =============================================================================
#  1. FUNCIÓN DE ROLLBACK (Red de Seguridad)
# =============================================================================
rollback() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "\n${RED}──────────────────────────────────────────────────────────────"
        warn "¡ERROR DETECTADO! Iniciando rollback automático de emergencia..."
        
        # 1. Restaurar Archivos
        if [ -f "${CONFIG_PATH}.bak" ]; then
            sudo cp "${CONFIG_PATH}.bak" "$CONFIG_PATH"
            sudo chown "$user_name:$user_name" "$CONFIG_PATH"
            info "Configuración de IPFS restaurada desde el backup."
        fi
        
        if [ -f "/etc/caddy/Caddyfile.bak" ]; then
            sudo cp "/etc/caddy/Caddyfile.bak" "/etc/caddy/Caddyfile"
            info "Caddyfile restaurado desde el backup."
        fi
        
        # 2. Intentar levantar servicios para evitar downtime
        info "Intentando reanudar servicios con la configuración previa..."
        if [[ "$INIT_SYSTEM" == "systemd" ]]; then
            sudo systemctl start ipfs || true
            sudo systemctl restart caddy || true
        else
            sudo -u "$user_name" nohup ipfs daemon > "$IPFS_PATH/ipfs.log" 2>&1 &
            sudo nohup caddy run --config /etc/caddy/Caddyfile --adapter caddyfile > /var/log/caddy_manual.log 2>&1 &
            disown
        fi
        
        warn "Rollback finalizado. El sistema debería estar en su estado anterior."
        echo -e "${RED}──────────────────────────────────────────────────────────────${NC}\n"
    fi
    exit $exit_code
}

# Activar el rollback ante cualquier error (ERR) o interrupción (SIGINT/SIGTERM)
trap rollback ERR SIGINT SIGTERM

# =============================================================================
#  2. ANÁLISIS DE REQUISITOS
# =============================================================================
banner "Análisis de Requisitos: RPC Seguro"

info "Sistema de inicio detectado: ${CYAN}$INIT_SYSTEM${NC}"

if ! command -v caddy &>/dev/null; then
    warn "Caddy no detectado. Instálalo con la Subopción 1."
    exit 1
fi

if ! command -v jq &>/dev/null; then
    info "Instalando jq para procesamiento JSON..."
    sudo apt update && sudo apt install -y jq
fi

# =============================================================================
#  3. RECOLECCIÓN DE CREDENCIALES
# =============================================================================
ask_credentials() {
    read -p "  🌐 Dominio para RPC (ej: rpc.tudominio.com): " DOMAIN
    read -p "  👤 Usuario para Autenticación: " RPC_USER
    
    while true; do
        read -s -p "  🔒 Contraseña para Autenticación: " RPC_PASS
        echo
        read -s -p "  🔒 Confirma la Contraseña: " RPC_PASS_CONFIRM
        echo
        
        if [[ "$RPC_PASS" == "$RPC_PASS_CONFIRM" ]]; then
            break
        else
            warn "Las contraseñas no coinciden. Inténtalo de nuevo."
        fi
    done
}

ask_credentials

if [[ -z "$DOMAIN" || -z "$RPC_USER" || -z "$RPC_PASS" ]]; then
    warn "Todos los campos son obligatorios."
    exit 1
fi

# --- RESUMEN ANTES DE APLICAR ---
echo -e "\n  ${YELLOW}┌─────────────────────────────────────────────┐"
printf "  │  %-43s│\n" "RESUMEN DE CONFIGURACIÓN GATEWAY + RPC"
echo "  ├─────────────────────────────────────────────┤"
printf "  │  %-20s %-22s│\n" "Dominio:" "$DOMAIN"
printf "  │  %-20s %-22s│\n" "Usuario RPC:" "$RPC_USER"
printf "  │  %-20s %-22s│\n" "Sistema Init:" "$INIT_SYSTEM"
printf "  │  %-20s %-22s│\n" "Acceso WebUI:" "Habilitado (CORS)"
echo -e "  └─────────────────────────────────────────────┘${NC}\n"

if ! confirm "¿Deseas aplicar esta configuración de seguridad ahora?"; then
    info "Operación cancelada por el usuario."
    exit 0
fi

# =============================================================================
#  4. EJECUCIÓN
# =============================================================================
banner "Aplicando Configuración"

# --- Backups Reales ---
info "Creando backups de seguridad..."
sudo cp "$CONFIG_PATH" "${CONFIG_PATH}.bak"
[[ -f /etc/caddy/Caddyfile ]] && sudo cp /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.bak"

info "Deteniendo servicios para configuración segura..."
if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    sudo systemctl stop ipfs || true
    sudo systemctl stop caddy || true
else
    sudo -u "$user_name" pkill -x ipfs || true
    sudo pkill -x caddy || true
fi
sleep 1

# --- Inyección con JQ ---
info "Configurando AuthSecret y CORS en IPFS..."
FULL_DOMAIN="https://$DOMAIN"

sudo jq \
  --arg domain "$FULL_DOMAIN" \
  --arg user "$RPC_USER" \
  --arg pass "$RPC_PASS" \
  '
  .API.HTTPHeaders = {
    "Access-Control-Allow-Origin": [$domain, "https://webui.ipfs.io"],
    "Access-Control-Allow-Credentials": ["true"]
  }
  | .API.Authorizations = {
      "api": {
        "AuthSecret": ("basic:" + $user + ":" + $pass),
        "AllowedPaths": ["/api/v0"]
      }
    }
  | .Addresses.Gateway = "/ip4/127.0.0.1/tcp/8080"  
  | .Addresses.Swarm = [
    "/ip4/0.0.0.0/tcp/4001",
    "/ip6/::/tcp/4001",
    "/ip4/0.0.0.0/tcp/8081/ws"
  ]
  ' "$CONFIG_PATH" > "${CONFIG_PATH}.tmp"

sudo mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"
sudo chown "$user_name:$user_name" "$CONFIG_PATH"

# --- Caddyfile ---
info "Actualizando Caddyfile..."
CADDY_CONTENT=$(cat <<EOF
# --- 1. WebSocket Swarm (Puerto 4002) ---
$DOMAIN:4002 {
    reverse_proxy localhost:8081
    
    # Nota: Caddy maneja automáticamente los headers de WebSocket (Upgrade/Connection)
}

# --- 2. Servidor Principal (Puerto 443): Gateway + RPC ---
$DOMAIN {

    # A. Manejo de CORS para la API (RPC)
    @api {
        path /api/v0*
    }
    
    handle @api {
        # Preflight para la WebUI
        @options {
            method OPTIONS
        }
        handle @options {
            header {
                Access-Control-Allow-Origin "https://webui.ipfs.io"
                Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
                Access-Control-Allow-Headers "*"
                Access-Control-Allow-Credentials "true"
            }
            respond 204
        }

        # Proxy al puerto 5001 (Kubo RPC)
        # Caddy NO usa buffering por defecto, así que tus 3.5GB fluirán sin errores.
        reverse_proxy localhost:5001 {
            header_up Host {host}
            # Caddy pasa los headers de Auth automáticamente
        }
    }

    # B. Manejo del Gateway (Todo lo que no sea /api/v0)
    handle {
        reverse_proxy localhost:8080
    }

    # Logs en formato JSON (opcional)
    log {
        output file /var/log/caddy/ipfs.log
        format json
    }
}
EOF
)
echo "$CADDY_CONTENT" | sudo tee /etc/caddy/Caddyfile > /dev/null

# =============================================================================
#  5. REINICIO MULTI-SISTEMA
# =============================================================================
banner "Reiniciando Servicios"

if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    info "Reiniciando vía systemctl..."
    sudo systemctl daemon-reload
    sudo systemctl start ipfs
    sudo systemctl restart caddy
else
    info "Iniciando IPFS de forma manual..."
    sudo -u "$user_name" nohup ipfs daemon > "$IPFS_PATH/ipfs.log" 2>&1 &
    info "Iniciando Caddy de forma manual..."
    sudo nohup caddy run --config /etc/caddy/Caddyfile --adapter caddyfile > /var/log/caddy_manual.log 2>&1 &
    disown
fi

# =============================================================================
#  6. VERIFICACIÓN FINAL
# =============================================================================
sleep 3
if pgrep -x "ipfs" > /dev/null && pgrep -x "caddy" > /dev/null; then
    banner "¡RPC Configurado Exitosamente!"
    info "Credenciales: ${CYAN}https://$RPC_USER:password@$DOMAIN${NC}"
    info "Pega las credenciles en https://webui.ipfs.io y accede a tu nodo."
    banner "¡Gateway Configurado Exitosamente!"
    info "Visita: https://${CYAN}$DOMAIN${NC}/ipfs/bafkreig24ijzqxj3cxdp6yh6ia2ysxzvxsfnd6rzahxxjv6ofcuix52wtq"
    info "Si ves el logo de IPFS, el Gateway fue configurado correctamente."
    echo ""
    info "Nota: Los backups (.bak) se mantendrán para referencia manual."
else
    # Si llegamos aquí y no hay procesos, forzamos el error para disparar el rollback
    warn "Los servicios no arrancaron tras la configuración. Activando rollback..."
    false 
fi