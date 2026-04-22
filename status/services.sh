#!/bin/bash

# ──────────────────────────────
# Configuración inicial
# ──────────────────────────────
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

CADDYFILE="/etc/caddy/Caddyfile"
ACTUAL_USER="${IPFS_USER:-${SUDO_USER:-$USER}}"

# Autodetección del Proxy (Nginx prioritario)
#if command -v caddy &>/dev/null || [[ -d /etc/caddy ]]; then
    WEB_SVC="caddy"
    WEB_NAME="Caddy Web Server"
#else
#    WEB_SVC="nginx"
#    WEB_NAME="Nginx Server"
#fi

# ──────────────────────────────
# Capa de Abstracción de Servicios (Agnóstica a init)
# ──────────────────────────────

# Evita el error "System has not been booted with systemd as init system"
is_systemd() {
    if [[ -d /run/systemd/system ]] || pidof systemd &>/dev/null; then
        return 0
    fi
    return 1
}

is_installed() {
    local srv=$1
    if is_systemd; then
        systemctl list-unit-files | grep -q "^${srv}.service" 2>/dev/null && return 0
    fi
    command -v "$srv" &>/dev/null && return 0
    return 1
}

is_active() {
    local srv=$1
    if is_systemd && systemctl list-unit-files | grep -q "^${srv}.service" 2>/dev/null; then
        systemctl is-active --quiet "$srv" 2>/dev/null && return 0
    fi
    pgrep -x "$srv" > /dev/null && return 0
    return 1
}

exec_start() {
    local srv=$1
    if is_systemd && systemctl list-unit-files | grep -q "^${srv}.service" 2>/dev/null; then
        sudo systemctl start "$srv"
    else
        # Fallback sin systemd
        if [[ "$srv" == "ipfs" ]]; then
            sudo -u "$ACTUAL_USER" nohup ipfs daemon > /dev/null 2>&1 &
        elif [[ "$srv" == "caddy" ]]; then
            nohup caddy run --config "$CADDYFILE" > /dev/null 2>&1 &
        elif [[ "$srv" == "nginx" ]]; then
            sudo nginx
        fi
    fi
}

exec_stop() {
    local srv=$1
    if is_systemd && systemctl list-unit-files | grep -q "^${srv}.service" 2>/dev/null; then
        sudo systemctl stop "$srv"
    else
        sudo pkill -x "$srv"
    fi
}

exec_enable() {
    local srv=$1
    if is_systemd && systemctl list-unit-files | grep -q "^${srv}.service" 2>/dev/null; then
        sudo systemctl enable "$srv" > /dev/null 2>&1
    fi
}

exec_disable() {
    local srv=$1
    if is_systemd && systemctl list-unit-files | grep -q "^${srv}.service" 2>/dev/null; then
        sudo systemctl disable "$srv" > /dev/null 2>&1
    fi
}

# ──────────────────────────────
# Funciones de UI e Inspección
# ──────────────────────────────

get_status() {
    local srv=$1
    if ! is_installed "$srv"; then
        echo -e "${YELLOW}⚪ No instalado${RESET}"
        return 1
    fi

    if is_active "$srv"; then
        echo -e "${GREEN}🟢 Activo${RESET}"
        return 0
    else
        echo -e "${RED}🔴 Inactivo${RESET}"
        return 2
    fi
}

detect_proxy_mode() {
    local has_gw=false
    local has_rpc=false
    local has_default=false

    # Detección Caddyfile
    if [[ -f "$CADDYFILE" ]]; then
        if grep -q "reverse_proxy localhost:8080" "$CADDYFILE"; then has_gw=true; fi
        if grep -q "reverse_proxy localhost:5001" "$CADDYFILE"; then has_rpc=true; fi
        if grep -q "https://caddyserver.com/docs/caddyfile" "$CADDYFILE"; then has_default=true; fi
    fi

    # Detección Nginx (Soporte cruzado)
    #if [[ "$WEB_SVC" == "nginx" ]]; then
    #    if grep -qr "http://localhost:8080" /etc/nginx/ 2>/dev/null; then has_gw=true; fi
    #    if grep -qr "http://localhost:5001" /etc/nginx/ 2>/dev/null; then has_rpc=true; fi
    #fi

    if $has_default; then
        echo -e "${CYAN}Ninguna${RESET}"  
    else    
            if $has_gw && $has_rpc; then
                echo -e "${CYAN}Gateway + RPC${RESET}"
            elif $has_gw; then
                echo -e "${CYAN}Solo Gateway${RESET}"
            elif $has_rpc; then
                echo -e "${CYAN}Solo RPC${RESET}"
            else
                echo -e "${YELLOW}No identificada / Personalizada${RESET}"
            fi
    fi  


}

toggle_service() {
    local service=$1
    local pretty_name=$2

    if ! is_installed "$service"; then
        echo -e "\n${RED}[!] El servicio $service no está instalado en el sistema.${RESET}"
        sleep 2
        return
    fi

    if is_active "$service"; then
        echo -e "\n${YELLOW}[*] Deteniendo $pretty_name...${RESET}"
        exec_stop "$service"
        sleep 1
        if ! is_active "$service"; then
            echo -e "${GREEN}[OK] $pretty_name detenido correctamente.${RESET}"
        else
            echo -e "${RED}[ERROR] No se pudo detener $pretty_name.${RESET}"
        fi
    else
        echo -e "\n${CYAN}[*] Iniciando $pretty_name...${RESET}"
        exec_start "$service"
        sleep 1
        if is_active "$service"; then
            echo -e "${GREEN}[OK] $pretty_name iniciado correctamente.${RESET}"
        else
            echo -e "${RED}[ERROR] Falló el inicio de $pretty_name.${RESET}"
            exec_stop "$service" # Rollback
        fi
    fi
    sleep 1.5
}

# ──────────────────────────────
# Bucle Principal del Gestor
# ──────────────────────────────
while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗"
    echo -e "║        🚥 Gestor de Servicios y Estado       ║"
    echo -e "╚══════════════════════════════════════════════╝${RESET}"
    echo ""
    
    echo -e "  📌 ${YELLOW}Estado actual de los servicios:${RESET}"
    printf "     %-25s %s\n" "IPFS (Kubo):" "$(get_status ipfs)"
    printf "     %-25s %s\n" "$WEB_NAME:" "$(get_status $WEB_SVC)"
    echo ""
    
    if is_installed "$WEB_SVC"; then
        echo -e "  ⚙️  ${YELLOW}Configuración Proxy activa:${RESET} $(detect_proxy_mode)"
        echo ""
    fi

    echo -e "  ──────────────────────────────────────────────"
    
    txt_ipfs="(Iniciar)"
    is_active ipfs && txt_ipfs="(Detener)"
    
    txt_web="(Iniciar)"
    is_active "$WEB_SVC" && txt_web="(Detener)"

    echo -e "  1) Alternar IPFS   $txt_ipfs"
    echo -e "  2) Alternar Caddy  $txt_web"
    echo -e "  3) Detener y Deshabilitar AMBOS (Apagado total)"
    echo -e "  4) Iniciar y Habilitar AMBOS (Encendido automático)"
    echo ""
    echo -e "  0) Volver al Menú Principal"
    echo ""

    read -p "  Selecciona una opción: " opt

    case $opt in
        1) toggle_service "ipfs" "Kubo (IPFS)" ;;
        2) toggle_service "$WEB_SVC" "$WEB_NAME" ;;
        3)
            echo -e "\n${RED}[!] Apagando toda la infraestructura...${RESET}"
            exec_stop ipfs
            exec_stop "$WEB_SVC"
            exec_disable ipfs
            exec_disable "$WEB_SVC"
            echo -e "${GREEN}[OK] Servicios detenidos y deshabilitados del arranque.${RESET}"
            sleep 2
            ;;
        4)
            echo -e "\n${CYAN}[*] Levantando infraestructura...${RESET}"
            exec_enable ipfs
            exec_enable "$WEB_SVC"
            exec_start ipfs
            exec_start "$WEB_SVC"
            echo -e "${GREEN}[OK] Servicios iniciados y habilitados en el arranque.${RESET}"
            sleep 2
            ;;
        0) break ;;
        *) echo -e "\n${RED}[!] Opción inválida${RESET}"; sleep 1 ;;
    esac
done