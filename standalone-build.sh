#!/bin/bash

OUTPUT="ipfs-manager-standalone.sh"

echo "[*] Iniciando compilación de IPFS Manager Standalone..."

# 1. Crear cabecera
echo "#!/bin/bash" > $OUTPUT
echo "# =========================================================" >> $OUTPUT
echo "# IPFS Manager CLI (Kubo Edition) - Standalone Build" >> $OUTPUT
echo "# Generado automáticamente: $(date)" >> $OUTPUT
echo "# =========================================================" >> $OUTPUT
echo "" >> $OUTPUT

# 2. Empaquetar módulos como funciones
for file in $(find cli gateway installer node repo status uninstaller -name "*.sh"); do
    
    # Generar el mismo nombre de función que espera invoke_module
    func_name=$(echo "$file" | sed 's/\//_/g' | sed 's/-/_/g' | sed 's/\.sh//g')
    
    echo "  -> Empaquetando: $file (como función: $func_name)"
    
    echo "function $func_name() {" >> $OUTPUT
    
    # Extraemos el contenido quitando el shebang (#!/bin/bash)
    # TRUCO MAGICO: Reemplazamos 'exit' por 'return' para no matar el script principal
    grep -v "^#!" "$file" | sed 's/\bexit\b/return/g' >> $OUTPUT
    
    echo "}" >> $OUTPUT
    echo "" >> $OUTPUT
done

# 3. Añadir el main.sh al final
echo "[*] Añadiendo main.sh..."
grep -v "^#!" main.sh >> $OUTPUT

# Dar permisos de ejecución
chmod +x $OUTPUT

echo "[+] ¡Compilación exitosa! Archivo generado: $OUTPUT"
