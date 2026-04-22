#!/bin/bash

# ──────────────────────────────
# Configuración inicial
# ──────────────────────────────
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="/etc/ipfs-metadata.env"

# Colores compartidos  
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m" 
RED="\033[1;31m"
RESET="\033[0m"

# ──────────────────────────────
# Cargar variables compartidas
# ──────────────────────────────
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    export TEMP_AUTH EMP_DOMAIN
fi

# ──────────────────────────────────────────
# Cargar credenciales al ejecutar el script:
# ──────────────────────────────────────────
# ~$ TEMP_AUTH=user:password TEMP_DOMAIN=midominio.com ./main.sh

# ==========================================
# Wrapper de Ejecución (Modular / Standalone)
# ==========================================
invoke_module() {
    local module_path="$1"
    
    # Convertimos la ruta "installer/ipfs-installer.sh" al nombre de función "installer_ipfs_installer"
    local func_name=$(echo "$module_path" | sed 's/\//_/g' | sed 's/-/_/g' | sed 's/\.sh//g')
    
    # Comprobamos si la función existe en memoria (Modo Standalone)
    if declare -f "$func_name" > /dev/null; then
        $func_name
    
    # Si la función no existe, comprobamos si el archivo físico existe (Modo Modular)
    elif [[ -f "$BASE_DIR/$module_path" ]]; then
        bash "$BASE_DIR/$module_path"
        
    else
        echo -e "\n\033[0;31m[ERROR] Módulo '$module_path' no encontrado.\033[0m"
        read -p "Presiona Enter para continuar..."
    fi
}

# =============================================================================
#  BUCLE MAESTRO DE LA APLICACIÓN
# =============================================================================
while true; do

    # ──────────────────────────────
    # Selección de Conexión
    # ──────────────────────────────
    while true; do
        clear
        ACTUAL_USER="${IPFS_USER:-${SUDO_USER:-$USER}}"
        USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
        CONFIG_PATH="$USER_HOME/.ipfs/config"

        echo -e "${CYAN}╔══════════════════════════════════════════════╗"
        echo -e "║          📡 Configuración de Conexión            ║"
        echo -e "╚══════════════════════════════════════════════╝${RESET}"
        echo ""
        
        if [[ -n "$TEMP_DOMAIN" ]]; then
            echo -e "  ${GREEN}¡Configuración detectada en memoria!${RESET}"
            echo -e "  Dominio: ${YELLOW}$TEMP_DOMAIN${RESET}"
            echo -e "  Credenciales: ${YELLOW}${TEMP_AUTH#basic:}${RESET}"            
            #echo -e "  Credenciales: ${YELLOW}$SUGGEST_USER${RESET}"
            echo ""
        fi

        # Estado de instalación con mensaje dinámico
        if command -v ipfs &>/dev/null; then
            IPFS_VER=$(ipfs --version | cut -d' ' -f3)
            echo -e "  Binario local: ${GREEN}Instalado ($IPFS_VER)${RESET}"
        else
            echo -e "  Binario local: ${RED}No Instalado (Selecciona opción 1 si deseas instalar)${RESET}"
        fi
        echo ""
        
        echo -e "  1) Conexión Local directa (Estándar) ${CYAN}[Predeterminada]${RESET}"
        echo -e "  2) Local por medio de RPC API (Localhost:5001)"
        echo -e "  3) Remota por medio de RPC API (Dominio personalizado)"
        echo -e "  4) Buscar credenciales en .config (Auto-detect)"
        echo ""
        echo -e "  0) Salir Completamente"
        echo ""
        
        read -p "  Selecciona el tipo de conexión [1]: " conn_opt
        conn_opt=${conn_opt:-1}

        case $conn_opt in
            1)
                export IPFS_CMD="sudo -u $ACTUAL_USER ipfs"
                export API=""
                export AUTH=""
                break 
                ;;
            2)
                export API="/ip4/127.0.0.1/tcp/5001"
                echo -e "\n${YELLOW}[Credenciales RPC Local]${RESET}"
                SUGGEST_USER=$(echo ${TEMP_AUTH#basic:} | cut -d: -f1)
                SUGGEST_PASS=$(echo ${TEMP_AUTH#basic:} | cut -d: -f2)
                
                read -p "  Usuario [${SUGGEST_USER:-admin}]: " rpc_user
                rpc_user=${rpc_user:-${SUGGEST_USER:-admin}}
                read -s -p "  Password [${SUGGEST_PASS:-(oculto)}]: " rpc_pass
                rpc_pass=${rpc_pass:-$SUGGEST_PASS}
                echo ""
                
                export AUTH="basic:$rpc_user:$rpc_pass"
                export IPFS_CMD="sudo -u $ACTUAL_USER ipfs --api $API --api-auth $AUTH"
                break
                ;;
            3)
                echo -e "\n${YELLOW}[Configuración de Nodo Remoto]${RESET}"
                read -p "  Dominio [${TEMP_DOMAIN:-mi-nodo.com}]: " rpc_domain
                # Limpiar https:// si el usuario lo escribe manualmente
                rpc_domain=${rpc_domain:-$TEMP_DOMAIN}
                rpc_domain=${rpc_domain#https://}
                rpc_domain=${rpc_domain#http://}
                
                export API="/dns/$rpc_domain/tcp/443/https"
                
                SUGGEST_USER=$(echo ${TEMP_AUTH#basic:} | cut -d: -f1)
                SUGGEST_PASS=$(echo ${TEMP_AUTH#basic:} | cut -d: -f2)

                read -p "  Usuario [${SUGGEST_USER:-admin}]: " rpc_user
                rpc_user=${rpc_user:-${SUGGEST_USER:-admin}}
                read -s -p "  Password [${SUGGEST_PASS:-(oculto)}]: " rpc_pass
                rpc_pass=${rpc_pass:-$SUGGEST_PASS}
                echo ""

                export AUTH="basic:$rpc_user:$rpc_pass"
                export IPFS_CMD="sudo -u $ACTUAL_USER ipfs --api $API --api-auth $AUTH"
                break
                ;;
            4)
                if ! command -v jq &>/dev/null; then
                    echo -e "\n${RED}[!] Error: 'jq' no instalado.${RESET}"
                    sleep 2; continue
                fi
                if [[ ! -f "$CONFIG_PATH" ]]; then
                    echo -e "\n${RED}[!] Error: No se encontró config.${RESET}"
                    sleep 2; continue
                fi

                echo -e "\n${GREEN}[OK]${RESET} Extrayendo datos..."
                TEMP_AUTH=$(jq -r '.API.Authorizations.api.AuthSecret // empty' "$CONFIG_PATH")
                # Extraer y eliminar https:// o http:// mediante sed
                TEMP_DOMAIN=$(jq -r '.API.HTTPHeaders["Access-Control-Allow-Origin"][]' "$CONFIG_PATH" 2>/dev/null | grep -v "webui.ipfs.io" | head -n 1 | sed -e 's|^https://||' -e 's|^http://||')

                if [[ -n "$TEMP_AUTH" && -n "$TEMP_DOMAIN" ]]; then
                    echo -e "  - Dominio: ${CYAN}$TEMP_DOMAIN${RESET}"
                    echo -e "  - Credenciales: ${CYAN}${TEMP_AUTH#basic:}${RESET}"
                    echo -e "\n${YELLOW}Datos guardados. Ahora selecciona opción 2 o 3 para aplicar.${RESET}"
                    sleep 3
                else
                    echo -e "\n${RED}[!] No se encontraron datos completos en config.${RESET}"
                    sleep 2
                fi
                continue 
                ;;
            0) exit 0 ;;
            *) echo -e "\n${RED}[!] Opción inválida.${RESET}"; sleep 1 ;;
        esac
    done

    export IPFS_USER=$ACTUAL_USER
    
    # ──────────────────────────────
    # Menú Principal
    # ──────────────────────────────
    while true; do
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════╗"
        echo -e "║                🪐 IPFS Suite Manager           ║"
        echo -e "╚══════════════════════════════════════════════╝${RESET}"
        
        if [ -n "$API" ]; then
            echo -e "  Conexión: ${YELLOW}RPC ($API)${RESET}"
        else
            echo -e "  Conexión: ${GREEN}Local Directa${RESET}"
        fi

        if command -v ipfs &>/dev/null; then
            IPFS_VER=$(ipfs --version | cut -d' ' -f3)
            echo -e "  Estado: ${GREEN}Instalado ($IPFS_VER)${RESET}"
        else
            echo -e "  Estado: ${RED}No Instalado (Selecciona opción 1 si deseas instalar)${RESET}"
        fi
        echo ""
        
        echo "  1) Instalar IPFS (kubo)"
        echo "  2) Configurar Repo (init)"
        echo "  3) Configurar Nodo (daemon)"
        echo "  4) Configurar Gateway & RPC (Path / WebUI)"
        echo "  5) Desactivar Kubo, Gateway & RPC"
        echo "  6) Consola de Gestión (CLI / MFS / Swarm)"
        echo "  7) Desinstalar (kubo / Caddy)"
        echo ""
        echo "  0) Volver al Menú de Conexión"
        echo ""

        read -p "  Selecciona una opción: " opt

        case $opt in
            1)
                echo -e "\n${YELLOW}[INFO] Iniciando instalador...${RESET}"
                #sudo bash "$BASE_DIR/installer/ipfs-installer.sh"
                #read -p "Presiona Enter para volver..."
                #;;
                invoke_module "installer/ipfs-installer.sh" ;;
            2)
                #bash "$BASE_DIR/repo/init.sh"
                #read -p "Presiona Enter para volver..."
                #;;
                invoke_module "repo/init.sh" ;;
            3)
                #sudo bash "$BASE_DIR/node/daemon.sh"
                #read -p "Presiona Enter para volver..."
                #;;
                invoke_module "node/daemon.sh" ;;
            4)
                while true; do
                    clear
                    echo -e "${CYAN}╔══════════════════════════════════════════════╗"
                    echo -e "║        🌐 Configurar Gateway & RPC           ║"
                    echo -e "╚══════════════════════════════════════════════╝${RESET}"
                    echo ""
                    echo -e "  1) Instalar Caddy Server"
                    echo -e "  2) Configurar Acceso por PATH (Gateway)"
                    echo -e "  3) Configurar Acceso RPC (API + WebUI)"
                    echo -e "  4) Configurar Ambos (PATH + RPC)"
                    echo -e "  5) Desactivar (PATH - RPC)"
                    echo ""
                    echo -e "  0) Volver al Menú Principal"
                    echo ""

                    read -p "  Selecciona una opción: " subopt

                    case $subopt in
                        1)
                            #sudo bash "$BASE_DIR/gateway/caddy-installer.sh"
                            #read -p "Presiona Enter para volver..."
                            #;;
                            invoke_module "gateway/caddy-installer.sh" ;;
                        2)
                            #sudo bash "$BASE_DIR/gateway/path.sh"
                            #read -p "Presiona Enter para volver..."
                            #;;
                            invoke_module "gateway/path.sh" ;;
                        3)
                            #sudo bash "$BASE_DIR/gateway/RPC.sh"
                            #read -p "Presiona Enter para volver..."
                            #;;
                            invoke_module "gateway/RPC.sh" ;;
                        4)
                            #sudo bash "$BASE_DIR/gateway/path+RPC.sh"
                            #read -p "Presiona Enter para volver..."
                            #;;
                            invoke_module "gateway/path+RPC.sh" ;;
                        5)
                            #sudo bash "$BASE_DIR/gateway/disable.sh"
                            #read -p "Presiona Enter para volver..."
                            #;;
                            invoke_module "gateway/disable.sh" ;;                     
                        0) break ;; 
                        *) echo -e "\n${RED}Opción inválida${RESET}"; sleep 1 ;;
                    esac
                done
                ;;
            5)
                #sudo bash "$BASE_DIR/status/services.sh"
                #read -p "Presiona Enter para volver..."
                #;;
                invoke_module "status/services.sh" ;;
            6)  
                #bash "$BASE_DIR/cli/ipfs-cli.sh"
                #read -p "Presiona Enter para volver..."
                #;;
                invoke_module "cli/ipfs-cli.sh" ;;
            7)
                echo -e "${RED}¡ATENCIÓN! Vas a eliminar componentes del sistema.${RESET}"
                echo "  a) Desinstalar Caddy"
                echo "  b) Desinstalar IPFS (Kubo)"
                read -p "  Elige opción [a/b]: " rm_opt
                if [[ "$rm_opt" == "a" ]]; then
                    #sudo bash "$BASE_DIR/uninstaller/uninstaller-caddy.sh"
                    invoke_module "uninstaller/uninstaller-caddy.sh" 
                elif [[ "$rm_opt" == "b" ]]; then
                    invoke_module "uninstaller/uninstaller-ipfs.sh"
                fi
                read -p "Presiona Enter para volver..."
                ;;                      
            0) 
                echo -e "\n${YELLOW}Regresando al menú de conexión...${RESET}"
                sleep 0.5
                break # Rompe el bucle del Menú Principal y vuelve al Bucle Maestro
                ;;
            *) 
                echo -e "\n${RED}Opción inválida${RESET}"
                sleep 1 
                ;;
        esac
    done

done # Fin del Bucle Maestro
