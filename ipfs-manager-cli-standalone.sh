#!/bin/bash
# =========================================================
# IPFS Manager CLI (Kubo Edition) - Standalone Build
# Generado automáticamente: mar 21 abr 2026 21:18:32 CST
# =========================================================

function cli_ipfs_cli() {

# ──────────────────────────────
#  Configuración de conexión
# ──────────────────────────────
# local RPC node
#API="/ip4/127.0.0.1/tcp/5001"
# remote RPC reverse proxy
#API="/dns/midominio.com.contaboserver.net/tcp/443/https"
# user and password from .ipfs/config file
#AUTH="basic:USER:PASSWORD"
# ipfs command string
#IPFS="ipfs --api $API --api-auth $AUTH"
#IPFS="ipfs "

# ──────────────────────────────
#  Configuración de conexión (Dinámica)
# ──────────────────────────────
# Si las variables vienen de main.sh, se usan. Si no, se usan los valores por defecto.

# 1. Definir API (Prioriza la de main.sh, si no, usa una local por defecto)
#API="${API:-/ip4/127.0.0.1/tcp/5001}"
#API="${API:-/dns/midominio.com/tcp/443/https}"
# 2. Definir AUTH (Prioriza la de main.sh)
#AUTH="${AUTH:-}"

# 3. Definir el comando IPFS principal
# Si existe IPFS_CMD (definido en main.sh con sudo y flags), lo usamos.
# Si no, construimos el comando manualmente para uso independiente.
if [ -n "$IPFS_CMD" ]; then
    IPFS="$IPFS_CMD"
else
    # Lógica para ejecución independiente del script
    if [ -n "$AUTH" ]; then
        IPFS="ipfs --api $API --api-auth $AUTH"
    else
        IPFS="ipfs --api $API"
    fi
fi

# ──────────────────────────────
#  Colores
# ──────────────────────────────
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# ──────────────────────────────
#  Utilidades
# ──────────────────────────────
pause() { echo; read -p "Presiona Enter para continuar..."; }

ask() { read -p "$1" "$2"; }

header() {
  clear
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║           🪐  IPFS Node Manager              ║"
  echo "╚══════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

# ──────────────────────────────
#  Árbol MFS recursivo
# ──────────────────────────────
#  Navegador MFS para seleccionar origen existente
#  Devuelve path en $MFS_ORIGEN
# ──────────────────────────────
seleccionar_mfs_origen() {
  local dir="/"
  MFS_ORIGEN=""

  while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗"
    echo -e "║         🗂️  Seleccionar origen en MFS        ║"
    echo -e "╚══════════════════════════════════════════════╝${RESET}"
    echo -e "${YELLOW}  Ubicación MFS: ${GREEN}$dir${RESET}"
    echo

    local items=()
    items+=("..")
    local entries
    entries=$($IPFS files ls "$dir" 2>/dev/null)
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      local full="${dir%/}/$entry"
      full="${full//\/\//\/}"
      local tipo
      tipo=$($IPFS files stat --format="<type>" "$full" 2>/dev/null)
      if [ "$tipo" = "directory" ]; then
        items+=("📁 $entry/")
      else
        items+=("📄 $entry")
      fi
    done <<< "$entries"

    for i in "${!items[@]}"; do
      printf "  %3d) %s\n" "$((i+1))" "${items[$i]}"
    done

    echo
    echo -e "  ${GREEN}S) Seleccionar este directorio: $dir${RESET}"
    echo "  0) Cancelar"
    echo
    ask "Opción: " sel

    if [[ "$sel" == "0" ]]; then
      MFS_ORIGEN=""
      return 1
    fi

    if [[ "$sel" == "s" || "$sel" == "S" ]]; then
      MFS_ORIGEN="$dir"
      return 0
    fi

    if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#items[@]} )); then
      echo -e "${RED}Opción inválida${RESET}"; sleep 1; continue
    fi

    local elegido="${items[$((sel-1))]}"

    if [[ "$elegido" == ".." ]]; then
      [ "$dir" != "/" ] && dir="$(dirname "${dir%/}")"
      [ -z "$dir" ] && dir="/"
      continue
    fi

    if [[ "$elegido" == 📁* ]]; then
      local nombre
      nombre=$(echo "$elegido" | sed 's/^📁 //' | sed 's|/$||')
      dir="${dir%/}/$nombre"
      dir="${dir//\/\//\/}"
      continue
    fi

    # Es archivo — seleccionar directamente
    if [[ "$elegido" == 📄* ]]; then
      local nombre
      nombre=$(echo "$elegido" | sed 's/^📄 //')
      MFS_ORIGEN="${dir%/}/$nombre"
      MFS_ORIGEN="${MFS_ORIGEN//\/\//\/}"
      return 0
    fi
  done
}


# ──────────────────────────────
seleccionar_mfs() {
  local nombre_default="${1:-}"
  local dir="/"
  MFS_SELECCIONADO=""

  while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗"
    echo -e "║         🗂️  Destino en MFS                   ║"
    echo -e "╚══════════════════════════════════════════════╝${RESET}"
    echo -e "${YELLOW}  Ubicación MFS: ${GREEN}$dir${RESET}"
    echo

    local items=()
    items+=("..")
    local entries
    entries=$($IPFS files ls "$dir" 2>/dev/null)
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      local full="$dir/$entry"
      full="${full//\/\//\/}"
      local tipo
      tipo=$($IPFS files stat --format="<type>" "$full" 2>/dev/null)
      if [ "$tipo" = "directory" ]; then
        items+=("📁 $entry/")
      else
        items+=("📄 $entry")
      fi
    done <<< "$entries"

    for i in "${!items[@]}"; do
      printf "  %3d) %s\n" "$((i+1))" "${items[$i]}"
    done

    echo
    echo -e "  ${GREEN}S) Guardar aquí → ${dir%/}/$nombre_default${RESET}"
    echo -e "  ${YELLOW}M) Escribir ruta manualmente${RESET}"
    echo "  0) Cancelar"
    echo
    ask "Opción: " sel

    if [[ "$sel" == "0" ]]; then
      MFS_SELECCIONADO=""
      return 1
    fi

    if [[ "$sel" == "s" || "$sel" == "S" ]]; then
      local base="$dir"
      [[ "$base" != /* ]] && base="/$base"
      if [ "$base" = "/" ]; then
        MFS_SELECCIONADO="/$nombre_default"
      else
        MFS_SELECCIONADO="${base%/}/$nombre_default"
      fi
      MFS_SELECCIONADO="${MFS_SELECCIONADO//\/\//\/}"
      return 0
    fi

    if [[ "$sel" == "m" || "$sel" == "M" ]]; then
      ask "Ruta MFS completa: " ruta_manual
      MFS_SELECCIONADO="$ruta_manual"
      return 0
    fi

    if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#items[@]} )); then
      echo -e "${RED}Opción inválida${RESET}"; sleep 1; continue
    fi

    local elegido="${items[$((sel-1))]}"

    if [[ "$elegido" == ".." ]]; then
      [ "$dir" != "/" ] && dir="$(dirname "${dir%/}")"
      [ -z "$dir" ] && dir="/"
      continue
    fi

    if [[ "$elegido" == 📁* ]]; then
      local nombre
      nombre=$(echo "$elegido" | sed 's/^📁 //' | sed 's|/$||')
      dir="${dir%/}/$nombre"
      dir="${dir//\/\//\/}"
      continue
    fi
  done
}


menu_nodo() {
  while true; do
    header
    echo -e "${YELLOW}[ INFO DEL NODO ]${RESET}"
    echo "  1) Identidad del nodo (id)"
    echo "  2) Versión de IPFS"
    echo "  3) Estadísticas del repositorio"
    echo "  4) Ancho de banda (stats bw)"
    echo "  5) Estadísticas de Bitswap"
    echo "  6) Info del sistema (diag sys)"
    echo "  7) Comandos activos (diag cmds)"
    echo "  0) Volver"
    echo
    ask "Opción: " opt
    case $opt in
      1) $IPFS id; pause ;;
      2) $IPFS version; pause ;;
      3) $IPFS repo stat -H; pause ;;
      4) echo -e "${YELLOW}Mostrando ancho de banda cada 1s — Ctrl+C para detener${RESET}"; $IPFS stats bw --poll -i 1s; pause ;;
      5) $IPFS stats bitswap -v --human; pause ;;
      6) $IPFS diag sys; pause ;;
      7) $IPFS diag cmds; pause ;;
      0) break ;;
      *) echo -e "${RED}Opción inválida${RESET}"; sleep 1 ;;
    esac
  done
}

# ──────────────────────────────
#  Selector interactivo de archivos/directorios
#  Uso: seleccionar_ruta [archivo|directorio]
#  Devuelve la ruta en $RUTA_SELECCIONADA
# ──────────────────────────────
seleccionar_ruta() {
  local modo="${1:-archivo}"  # "archivo" o "directorio"
  local dir="/home"
  RUTA_SELECCIONADA=""

  while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗"
    echo -e "║         📂  Selector de $modo               ║"
    echo -e "╚══════════════════════════════════════════════╝${RESET}"
    echo -e "${YELLOW}  Ubicación: ${GREEN}$dir${RESET}"
    echo

    # Construir lista: .. primero, luego directorios, luego archivos
    local items=()
    items+=("..")
    while IFS= read -r d; do
      items+=("📁 $(basename "$d")/")
    done < <(find "$dir" -maxdepth 1 -mindepth 1 -type d | sort)
    if [[ "$modo" == "archivo" ]]; then
      while IFS= read -r f; do
        items+=("📄 $(basename "$f")")
      done < <(find "$dir" -maxdepth 1 -mindepth 1 -type f | sort)
    fi

    # Mostrar numerado
    for i in "${!items[@]}"; do
      printf "  %3d) %s\n" "$((i+1))" "${items[$i]}"
    done

    echo
    if [[ "$modo" == "directorio" ]]; then
      echo -e "  ${GREEN}S) Seleccionar este directorio: $dir${RESET}"
    fi
    echo "  0) Cancelar"
    echo
    ask "Opción: " sel

    # Cancelar
    if [[ "$sel" == "0" ]]; then
      RUTA_SELECCIONADA=""
      return 1
    fi

    # Seleccionar directorio actual (modo directorio)
    if [[ "$modo" == "directorio" && ( "$sel" == "s" || "$sel" == "S" ) ]]; then
      RUTA_SELECCIONADA="$dir"
      return 0
    fi

    # Validar número
    if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#items[@]} )); then
      echo -e "${RED}Opción inválida${RESET}"; sleep 1; continue
    fi

    local elegido="${items[$((sel-1))]}"

    # Subir un nivel
    if [[ "$elegido" == ".." ]]; then
      dir="$(dirname "$dir")"
      continue
    fi

    # Es directorio
    if [[ "$elegido" == 📁* ]]; then
      local nombre
      nombre=$(echo "$elegido" | sed 's/^📁 //' | sed 's|/$||')
      dir="$dir/$nombre"
      continue
    fi

    # Es archivo (solo en modo archivo)
    if [[ "$elegido" == 📄* ]]; then
      local nombre
      nombre=$(echo "$elegido" | sed 's/^📄 //')
      RUTA_SELECCIONADA="$dir/$nombre"
      return 0
    fi
  done
}

# ══════════════════════════════════════════════
#  2. ARCHIVOS — ipfs add / get / cat / ls
# ══════════════════════════════════════════════
menu_archivos() {
  while true; do
    header
    echo -e "${YELLOW}[ ARCHIVOS ]${RESET}"
    echo "  1) Agregar archivo a IPFS (add)"
    echo "  2) Agregar directorio recursivo (add -r)"
    echo "  3) Descargar desde MFS a local"
    echo "  4) Agregar y guardar en MFS (add --to-files)"
    echo "  5) Descargar contenido por CID (get)"
    echo "  6) Ver contenido por CID (cat)"
    echo "  7) Listar links de un CID (ls)"
    echo "  8) Stats de un DAG (dag stat)"
    echo "  9) Exportar DAG como .car (dag export)"
    echo " 10) Importar .car (dag import)"
    echo "  0) Volver"
    echo
    ask "Opción: " opt
    case $opt in
      1)
        seleccionar_ruta "archivo"
        if [ -z "$RUTA_SELECCIONADA" ]; then pause; continue; fi
        local nombre_archivo
        nombre_archivo=$(basename "$RUTA_SELECCIONADA")
        seleccionar_mfs "$nombre_archivo"
        if [ -z "$MFS_SELECCIONADO" ]; then pause; continue; fi
        echo -e "${GREEN}Agregando: $RUTA_SELECCIONADA${RESET}"
        local cid
        cid=$($IPFS add -Q -p --preserve-mode --preserve-mtime "$RUTA_SELECCIONADA")
        if [ -z "$cid" ]; then
          echo -e "${RED}Error al agregar el archivo.${RESET}"
          pause; continue
        fi
        echo -e "${GREEN}CID obtenido: $cid${RESET}"
        echo -e "${GREEN}Copiando a MFS: $MFS_SELECCIONADO${RESET}"
        $IPFS files cp /ipfs/"$cid" "$MFS_SELECCIONADO"
        echo -e "${GREEN}✅ Listo. Archivo disponible en MFS: $MFS_SELECCIONADO${RESET}"
        pause ;;
      2)
        seleccionar_ruta "directorio"
        if [ -z "$RUTA_SELECCIONADA" ]; then pause; continue; fi
        local nombre_dir
        nombre_dir=$(basename "$RUTA_SELECCIONADA")
        seleccionar_mfs "$nombre_dir"
        if [ -z "$MFS_SELECCIONADO" ]; then pause; continue; fi
        ask "¿Agregar sin pin? (s/n): " nopin
        echo -e "${GREEN}Agregando directorio: $RUTA_SELECCIONADA${RESET}"
        local cid
        if [[ "$nopin" =~ ^[Ss]$ ]]; then
          cid=$($IPFS add -r -Q -p --preserve-mode --preserve-mtime --pin=false  "$RUTA_SELECCIONADA")
        else
          cid=$($IPFS add -r -Q -p --preserve-mode --preserve-mtime "$RUTA_SELECCIONADA")
        fi
        if [ -z "$cid" ]; then
          echo -e "${RED}Error al agregar el directorio.${RESET}"
          pause; continue
        fi
        echo -e "${GREEN}CID obtenido: $cid${RESET}"
        echo -e "${GREEN}Copiando a MFS: $MFS_SELECCIONADO${RESET}"
        $IPFS files cp /ipfs/"$cid" "$MFS_SELECCIONADO"
        echo -e "${GREEN}✅ Listo. Directorio disponible en MFS: $MFS_SELECCIONADO${RESET}"
        pause ;;
      3)
        seleccionar_mfs_origen
        if [ -z "$MFS_ORIGEN" ]; then pause; continue; fi
        local cid_origen
        cid_origen=$($IPFS files stat --format="<hash>" "$MFS_ORIGEN" 2>/dev/null)
        if [ -z "$cid_origen" ]; then
          echo -e "${RED}Error: no se pudo obtener el CID de $MFS_ORIGEN${RESET}"
          pause; continue
        fi
        echo -e "${CYAN}  Origen MFS : $MFS_ORIGEN${RESET}"
        echo -e "${CYAN}  CID        : $cid_origen${RESET}"
        echo
        seleccionar_ruta "directorio"
        if [ -z "$RUTA_SELECCIONADA" ]; then pause; continue; fi
        local nombre_base
        nombre_base=$(basename "$MFS_ORIGEN")
        local destino_local="$RUTA_SELECCIONADA/$nombre_base"
        echo -e "${GREEN}Descargando hacia: $destino_local${RESET}"
        $IPFS get /ipfs/"$cid_origen" -o "$destino_local"
        echo -e "${GREEN}✅ Listo. Guardado en: $destino_local${RESET}"
        pause ;;
      4)
        seleccionar_ruta "directorio"
        if [ -z "$RUTA_SELECCIONADA" ]; then pause; continue; fi
        ask "Destino en MFS (ej: /galeria): " dest
        $IPFS add -r -Q -p --to-files --preserve-mode --preserve-mtime "$dest" "$RUTA_SELECCIONADA"
        pause ;;
      5)
        ask "CID a descargar: " cid
        ask "Directorio de destino (Enter = actual): " dest
        if [ -z "$dest" ]; then
          $IPFS get "$cid"
        else
          $IPFS get -o "$dest" "$cid"
        fi
        pause ;;
      6)
        ask "CID o path: " cid
        $IPFS cat "$cid"
        pause ;;
      7)
        ask "CID o path: " cid
        $IPFS ls -v -l "$cid"
        pause ;;
      8)
        ask "CID: " cid
        $IPFS dag stat "$cid"
        pause ;;
      9)
        ask "CID raíz: " cid
        ask "Archivo de salida (.car): " out
        $IPFS dag export "$cid" > "$out"
        echo -e "${GREEN}Exportado a $out${RESET}"
        pause ;;
      10)
        ask "Archivo .car: " archivo
        $IPFS dag import "$archivo"
        pause ;;
      0) break ;;
      *) echo -e "${RED}Opción inválida${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  3. MFS — Mutable File System
# ══════════════════════════════════════════════
menu_mfs() {
  while true; do
    header
    echo -e "${YELLOW}[ MFS — Mutable File System ]${RESET}"
    echo "  1) Gestionar MFS (navegador interactivo)"
    echo "  2) Crear directorio MFS (files mkdir)"
    echo "  3) Copiar CID al MFS (files cp)"
    echo "  4) Mover archivo en MFS (files mv)"
    echo "  5) Eliminar archivo/dir MFS (files rm)"
    echo "  6) Info de un path MFS (files stat)"
    echo "  7) Leer archivo MFS (files read)"
    echo "  8) Flush MFS (files flush)"
    echo "  0) Volver"
    echo
    ask "Opción: " opt
    case $opt in
      1)
        seleccionar_mfs_origen
        pause ;;
      2)
        ask "Path a crear: " path
        $IPFS files mkdir -p "$path"
        pause ;;
      3)
        ask "CID fuente (ej: /ipfs/Qm...): " cid
        echo
        echo -e "${CYAN}  ¿Es un archivo o directorio?${RESET}"
        echo "  1) Archivo"
        echo "  2) Directorio"
        ask "Tipo: " tipo_cp
        echo -e "${CYAN}  Navegá al directorio destino en MFS:${RESET}"
        seleccionar_mfs_origen
        if [ -z "$MFS_ORIGEN" ]; then pause; continue; fi
        local dir_destino="$MFS_ORIGEN"
        local stat_tipo
        stat_tipo=$($IPFS files stat --format="<type>" "$dir_destino" 2>/dev/null)
        [ "$stat_tipo" != "directory" ] && dir_destino=$(dirname "$dir_destino")
        # Garantizar que empiece con /
        [[ "$dir_destino" != /* ]] && dir_destino="/$dir_destino"
        # Normalizar doble slash
        dir_destino="${dir_destino//\/\//\/}"
        if [[ "$tipo_cp" == "1" ]]; then
          ask "Nombre del archivo (con extensión, ej: foto.jpg): " nombre_dest
        else
          ask "Nombre del directorio: " nombre_dest
        fi
        local dest_final
        if [ "$dir_destino" = "/" ]; then
          dest_final="/$nombre_dest"
        else
          dest_final="${dir_destino%/}/$nombre_dest"
        fi
        echo -e "${GREEN}Copiando $cid → $dest_final${RESET}"
        $IPFS files cp "$cid" "$dest_final"
        echo -e "${GREEN}✅ Listo. Disponible en MFS: $dest_final${RESET}"
        pause ;;
      4)
        ask "Origen MFS: " src
        ask "Destino MFS: " dest
        $IPFS files mv "$src" "$dest"
        pause ;;
      5)
        ask "Path a eliminar: " path
        ask "¿Es directorio? (s/n): " esdir
        if [[ "$esdir" =~ ^[Ss]$ ]]; then
          $IPFS files rm -r "$path"
        else
          $IPFS files rm "$path"
        fi
        pause ;;
      6)
        ask "Path MFS (Enter = /): " path
        path="${path:-/}"
        $IPFS files stat "$path"
        pause ;;
      7)
        ask "Path del archivo en MFS: " path
        $IPFS files read "$path"
        pause ;;
      8)
        ask "Path a flushear (Enter = /): " path
        path="${path:-/}"
        $IPFS files flush "$path"
        pause ;;
      0) break ;;
      *) echo -e "${RED}Opción inválida${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  4. PINS
# ══════════════════════════════════════════════
menu_pins() {
  while true; do
    header
    echo -e "${YELLOW}[ PINS ]${RESET}"
    echo "  1) Listar pins"
    echo "  2) Agregar pin (pin add)"
    echo "  3) Eliminar pin (pin rm)"
    echo "  4) Verificar pins (pin verify)"
    echo "  0) Volver"
    echo
    ask "Opción: " opt
    case $opt in
      1)
        echo -e "  a) Todos  b) Recursivos  c) Directos  d) Indirectos"
        ask "Tipo (Enter = todos): " tipo
        case $tipo in
          b) $IPFS pin ls --type=recursive ;;
          c) $IPFS pin ls --type=direct ;;
          d) $IPFS pin ls --type=indirect ;;
          *) $IPFS pin ls ;;
        esac
        pause ;;
      2)
        ask "CID a pinear: " cid
        $IPFS pin add "$cid"
        pause ;;
      3)
        ask "CID a despinear: " cid
        $IPFS pin rm "$cid"
        pause ;;
      4)
        $IPFS pin verify
        pause ;;
      0) break ;;
      *) echo -e "${RED}Opción inválida${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  5. RED — Swarm y peers
# ══════════════════════════════════════════════
menu_red() {
  while true; do
    header
    echo -e "${YELLOW}[ RED / SWARM ]${RESET}"
    echo "  1) Peers conectados (swarm peers)"
    echo "  2) Direcciones del nodo (swarm addrs local)"
    echo "  3) Conectar a peer (swarm connect)"
    echo "  4) Desconectar peer (swarm disconnect)"
    echo "  5) Buscar peer en DHT (routing findpeer)"
    echo "  6) Buscar proveedores de CID (routing findprovs)"
    echo "  7) Ping a un peer"
    echo "  8) Listar bootstrap peers"
    echo "  0) Volver"
    echo
    ask "Opción: " opt
    case $opt in
      1) $IPFS swarm peers; pause ;;
      2) $IPFS swarm addrs local; pause ;;
      3)
        ask "Multiaddr del peer: " peer
        $IPFS swarm connect "$peer"
        pause ;;
      4)
        ask "Multiaddr del peer: " peer
        $IPFS swarm disconnect "$peer"
        pause ;;
      5)
        ask "PeerID: " peer
        $IPFS routing findpeer "$peer"
        pause ;;
      6)
        ask "CID: " cid
        $IPFS routing findprovs "$cid"
        pause ;;
      7)
        ask "PeerID: " peer
        $IPFS ping "$peer"
        pause ;;
      8)
        $IPFS bootstrap list
        pause ;;
      0) break ;;
      *) echo -e "${RED}Opción inválida${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  6. REPOSITORIO — GC y mantenimiento
# ══════════════════════════════════════════════
menu_repo() {
  while true; do
    header
    echo -e "${YELLOW}[ REPOSITORIO ]${RESET}"
    echo "  1) Stats del repo"
    echo "  2) Garbage collection (repo gc)"
    echo "  3) Verificar integridad (repo verify)"
    echo "  4) Ver CIDs locales (refs local)"
    echo "  5) Estadísticas de provide"
    echo "  0) Volver"
    echo
    ask "Opción: " opt
    case $opt in
      1) $IPFS repo stat; pause ;;
      2)
        echo -e "${RED}⚠️  Esto eliminará bloques sin pin ni referencia MFS${RESET}"
        ask "¿Confirmar? (s/n): " confirm
        if [[ "$confirm" =~ ^[Ss]$ ]]; then
          $IPFS repo gc
        fi
        pause ;;
      3) $IPFS repo verify; pause ;;
      4) $IPFS refs local; pause ;;
      5) $IPFS stats provide; pause ;;
      0) break ;;
      *) echo -e "${RED}Opción inválida${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  7. IPNS — Nombres y claves
# ══════════════════════════════════════════════
menu_ipns() {
  while true; do
    header
    echo -e "${YELLOW}[ IPNS / CLAVES ]${RESET}"
    echo "  1) Publicar CID en IPNS (name publish)"
    echo "  2) Resolver nombre IPNS (name resolve)"
    echo "  3) Actualizar lista de claves"
    echo "  4) Generar nueva clave (key gen)"
    echo "  5) Eliminar clave (key rm)"
    echo "  0) Volver"
    echo
    echo -e "${CYAN}  Claves disponibles:${RESET}"
    $IPFS key list -l 2>/dev/null | sed 's/^/    /'
    echo
    ask "Opción: " opt
    case $opt in
      1)
        echo -e "${CYAN}  Seleccioná el archivo o directorio del MFS a publicar:${RESET}"
        seleccionar_mfs_origen
        if [ -z "$MFS_ORIGEN" ]; then pause; continue; fi
        local cid_pub
        cid_pub=$($IPFS files stat --format="<hash>" "$MFS_ORIGEN" 2>/dev/null)
        if [ -z "$cid_pub" ]; then
          echo -e "${RED}Error: no se pudo obtener el CID de $MFS_ORIGEN${RESET}"
          pause; continue
        fi
        clear
        header
        echo -e "${CYAN}  Path MFS : $MFS_ORIGEN${RESET}"
        echo -e "${CYAN}  CID      : $cid_pub${RESET}"
        echo
        echo -e "${YELLOW}  Claves disponibles:${RESET}"
        $IPFS key list -l 2>/dev/null | sed 's/^/    /'
        echo
        ask "Nombre de clave (Enter = self): " clave
        clave="${clave:-self}"
        $IPFS name publish --key="$clave" /ipfs/"$cid_pub"
        pause ;;
      2)
        ask "Nombre IPNS o PeerID: " nombre
        $IPFS name resolve "$nombre"
        pause ;;
      3)
        echo -e "${GREEN}Lista actualizada.${RESET}"
        sleep 1 ;;
      4)
        ask "Nombre de la nueva clave: " nombre
        $IPFS key gen "$nombre"
        pause ;;
      5)
        ask "Nombre de la clave a eliminar: " nombre
        $IPFS key rm "$nombre"
        pause ;;
      0) break ;;
      *) echo -e "${RED}Opción inválida${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  8. COMANDO LIBRE
# ══════════════════════════════════════════════
menu_libre() {
  while true; do
    header
    echo -e "${YELLOW}[ COMANDO PERSONALIZADO ]${RESET}"
    echo "  Escribe el subcomando ipfs que quieras ejecutar."
    echo "  Ejemplo: files stat /  |  pin ls  |  swarm peers"
    echo ""
    echo "  #" 
    echo "  config --bool Provide.DHT.SweepEnabled true/false "
    echo "  Escribe '0' para volver al menú principal."
    echo
    ask "ipfs > " cmd
    [ "$cmd" = "0" ] && break
    $IPFS $cmd
    pause
  done
}

# ══════════════════════════════════════════════
#  MENÚ PRINCIPAL
# ══════════════════════════════════════════════
while true; do
  header
  #echo -e "${GREEN}  Nodo: $API${RESET}"
  #echo
  echo "  1) Info del nodo"
  echo "  2) Archivos (add / get / cat)"
  echo "  3) MFS (files ls / cp / rm...)"
  echo "  4) Pins"
  echo "  5) Red / Swarm"
  echo "  6) Repositorio y GC"
  echo "  7) IPNS y claves"
  echo "  8) Comando personalizado"
  echo
  echo "  0) Salir"
  echo
  ask "Opción: " opt
  case $opt in
    1) menu_nodo ;;
    2) menu_archivos ;;
    3) menu_mfs ;;
    4) menu_pins ;;
    5) menu_red ;;
    6) menu_repo ;;
    7) menu_ipns ;;
    8) menu_libre ;;
    #0) echo -e "${GREEN}Hasta luego.${RESET}"; return 0 ;;
    0) return 0 ;;
    *) echo -e "${RED}Opción inválida${RESET}"; sleep 1 ;;
  esac
done
}

function gateway_path+RPC() {

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
    return $exit_code
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
    return 1
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
    return 1
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
    return 0
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
}

function gateway_disable() {

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
    return 0
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
    return $exit_code
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
}

function gateway_path() {

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
    return 1
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
    return 1
fi

echo -e "\n  ${YELLOW}┌─────────────────────────────────────────────┐"
printf "  │  %-43s│\n" "RESUMEN DE OPERACIÓN (MODO SEGURO)"
echo "  ├─────────────────────────────────────────────┤"
printf "  │  %-20s %-22s│\n" "Usuario IPFS:" "$user_name"
printf "  │  %-20s %-22s│\n" "Dominio SSL:" "$DOMAIN"
printf "  │  %-20s %-22s│\n" "Método:" "Edición Offline (Evita Bloqueo RPC)"
echo -e "  └─────────────────────────────────────────────┘${NC}\n"

if ! confirm "¿Deseas aplicar esta configuración?"; then
    return 0
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
    return $exit_code
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
}

function gateway_caddy_installer() {

# =============================================================================
#  IPFS Gateway - Caddy Installation (Option 4 -> Sub 1)
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
DATE=$(date +"%Y%m%d-%H%M")

# =============================================================================
#  1. ANÁLISIS DE INSTALACIÓN (Idempotencia)
# =============================================================================
banner "Análisis de Caddy Server"

if command -v caddy &>/dev/null; then
    CADDY_VER=$(caddy version | awk '{print $1}')
    info "Caddy ya está presente en el sistema."
    echo -e "  - Versión: ${CYAN}$CADDY_VER${NC}"
    
    if systemctl is-active --quiet caddy; then
        echo -e "  - Estado:  ${GREEN}Servicio Activo${NC}"
    else
        echo -e "  - Estado:  ${RED}Servicio Inactivo/Detenido${NC}"
    fi
    echo ""
    if ! confirm "¿Deseas forzar la reinstalación o actualizar repositorios?"; then
        info "Saltando instalación. Caddy ya está listo."
        return 0
    fi
else
    info "Caddy no detectado. Iniciando proceso de instalación oficial..."
fi

# =============================================================================
#  2. CONFIGURACIÓN DE REPOSITORIOS
# =============================================================================
banner "Configurando Repositorios"

info "Instalando dependencias de transporte y llaves..."
sudo apt update
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

# Instalación de la llave oficial de Caddy
if [ ! -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg ]; then
    info "Descargando llave GPG de Caddy..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
    sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes
fi

# Configuración del source list
if [ ! -f /etc/apt/sources.list.d/caddy-stable.list ]; then
    info "Agregando repositorio oficial a sources.list.d..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
    sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
fi

# =============================================================================
#  3. INSTALACIÓN DEL BINARIO
# =============================================================================
banner "Ejecutando Instalación"

info "Actualizando índices de paquetes..."
sudo apt update

info "Instalando Caddy..."
sudo apt install -y caddy

# =============================================================================
#  4. GESTIÓN DEL SERVICIO
# =============================================================================
banner "Configuración de Servicio"

if [[ -d /run/systemd/system ]]; then
    info "Habilitando Caddy en Systemd para arranque automático..."
    sudo systemctl enable caddy
    sudo systemctl start caddy
    
    # Verificación rápida
    if systemctl is-active --quiet caddy; then
        info "Servicio Caddy: ${GREEN}OK${NC}"
    else
        warn "Caddy instalado pero el servicio no inició. Verifica con 'journalctl -u caddy'"
    fi
else
    warn "Systemd no detectado. Deberás iniciar Caddy manualmente:"
    echo -e "${CYAN}  sudo caddy run --config /etc/caddy/Caddyfile &${NC}"
fi

# =============================================================================
#  5. FINALIZACIÓN
# =============================================================================
banner "¡Caddy Instalado!"
info "El binario está listo en: ${CYAN}$(which caddy)${NC}"
info "Versión: ${GREEN}$(caddy version | awk '{print $1}')${NC}"
echo ""
info "Nota: El Caddyfile en /etc/caddy/Caddyfile se mantiene intacto."
info "Usa las siguientes subopciones para configurar el Proxy Inverso y CORS."
}

function gateway_RPC() {

# =============================================================================
#  IPFS Secure RPC & WebUI - Universal & Robust Rollback (Option 4 -> Sub 3)
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
    return $exit_code
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
    return 1
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
    return 1
fi

# --- RESUMEN ANTES DE APLICAR ---
echo -e "\n  ${YELLOW}┌─────────────────────────────────────────────┐"
printf "  │  %-43s│\n" "RESUMEN DE CONFIGURACIÓN RPC"
echo "  ├─────────────────────────────────────────────┤"
printf "  │  %-20s %-22s│\n" "Dominio:" "$DOMAIN"
printf "  │  %-20s %-22s│\n" "Usuario RPC:" "$RPC_USER"
printf "  │  %-20s %-22s│\n" "Sistema Init:" "$INIT_SYSTEM"
printf "  │  %-20s %-22s│\n" "Acceso WebUI:" "Habilitado (CORS)"
echo -e "  └─────────────────────────────────────────────┘${NC}\n"

if ! confirm "¿Deseas aplicar esta configuración de seguridad ahora?"; then
    info "Operación cancelada por el usuario."
    return 0
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
  | .Addresses.Swarm = ["/ip4/0.0.0.0/tcp/4001", "/ip4/0.0.0.0/tcp/8081/ws", "/ip6/::/tcp/4001"]
  ' "$CONFIG_PATH" > "${CONFIG_PATH}.tmp"

sudo mv "${CONFIG_PATH}.tmp" "$CONFIG_PATH"
sudo chown "$user_name:$user_name" "$CONFIG_PATH"

# --- Caddyfile ---
info "Actualizando Caddyfile..."
CADDY_CONTENT=$(cat <<EOF
$DOMAIN {
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

  handle {
    reverse_proxy localhost:5001
  }

  log {
    output stdout
    format json
    level INFO
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
    echo ""
    info "Nota: Los backups (.bak) se mantendrán para referencia manual."
else
    # Si llegamos aquí y no hay procesos, forzamos el error para disparar el rollback
    warn "Los servicios no arrancaron tras la configuración. Activando rollback..."
    false 
fi
}

function installer_ipfs_installer() {
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
trap 'echo ""; echo "❌  Error en línea $LINENO. Iniciando rollback..."; return 1' ERR

# =============================================================================
#  1. VERIFICAR QUE SE EJECUTA COMO ROOT
# =============================================================================
if [[ "$EUID" -ne 0 ]]; then
    error "Este script debe ejecutarse con sudo o como root."
    echo "  Uso: sudo bash ipfs-installer.sh"
    INSTALL_SUCCESSFUL=true
    return 1
fi

# =============================================================================
#  1b. VERIFICAR DISTRO COMPATIBLE (APT)
# =============================================================================
if [[ ! -f /etc/os-release ]]; then
    error "No se puede detectar el sistema operativo (/etc/os-release no existe)."
    INSTALL_SUCCESSFUL=true
    return 1
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
        return 1
    fi
fi

if ! command -v apt-get &>/dev/null; then
    error "No se encontró apt-get. Este script requiere un sistema basado en APT."
    INSTALL_SUCCESSFUL=true
    return 1
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
    return 1
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
        return 1
        ;;
    *)
        error "Arquitectura no soportada: $ARCH"
        echo "  Kubo solo publica builds para: amd64, arm64, riscv64."
        INSTALL_SUCCESSFUL=true
        return 1
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
            return 0
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
            return 0 
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
    return 1
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
    return 0
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
    return 1
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
            return 1
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
    return 1
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
}

function node_daemon() {

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
        return 0
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
    return 0
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
    return $exit_code
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
    return 1
fi
}

function repo_init() {

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
    return 0
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
}

function status_services() {

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
}

function uninstaller_uninstaller_caddy() {

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
    return 0
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
        return 0
        ;;
esac

# EXIGIR CONFIRMACIÓN ANTES DE TOCAR NADA
echo -e "\nModo seleccionado: ${YELLOW}$MODE${NC}"
info "$RESUMEN"

if ! confirm_final; then
    warn "Desinstalación abortada. No se han realizado cambios."
    return 0
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
}

function uninstaller_uninstaller_ipfs() {
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
    return 1
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
    return 1
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
    return 0
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
}


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
