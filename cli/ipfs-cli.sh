#!/bin/bash

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
    #0) echo -e "${GREEN}Hasta luego.${RESET}"; exit 0 ;;
    0) exit 0 ;;
    *) echo -e "${RED}Opción inválida${RESET}"; sleep 1 ;;
  esac
done
