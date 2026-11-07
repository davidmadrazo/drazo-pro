#!/bin/bash
# Pruebas de la versión de Node que elige el instalador de Mac (drazo-comun.sh), con un index.json real recortado
# de nodejs.org (fixtures/nodejs-dist). Sin red y sin instalar nada.
# Uso: bash tests/instalador-node.test.sh
raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixtures="$raiz/tests/fixtures/nodejs-dist"
# shellcheck source=../plugins/drazo/scripts/drazo-comun.sh
. "$raiz/plugins/drazo/scripts/drazo-comun.sh"

fallos=0
igual() {
    if [ "$2" = "$3" ]; then echo "ok    $1"; else echo "FALLA $1: esperaba «$3» y sale «$2»"; fallos=$((fallos + 1)); fi
}

# curl lee file:// con ruta de Windows en Git Bash (C:/...) y con la normal en Mac
ruta="$fixtures"
command -v cygpath >/dev/null 2>&1 && ruta="/$(cygpath -m "$fixtures")"
CON_RED="file://$ruta"
SIN_RED="http://127.0.0.1:9"
RESPALDO_REAL="$VERSION_NODE_RESPALDO"

igual "rama 24 de index.json" "$(elegir_version_node 24 < "$fixtures/index.json")" "24.22.1"
igual "rama 22 de index.json" "$(elegir_version_node 22 < "$fixtures/index.json")" "22.23.4"
igual "rama 20 de index.json" "$(elegir_version_node 20 < "$fixtures/index.json")" "20.20.2"
igual "rama que no está" "$(elegir_version_node 18 < "$fixtures/index.json")" ""

# Con un respaldo inventado, para distinguir lo que sale de index.json de lo que sale del respaldo
VERSION_NODE_RESPALDO="24.9.9"
URL_NODE_DIST="$CON_RED"
igual "instala la última 24 publicada" "$(version_node_a_instalar)" "24.22.1"
URL_NODE_DIST="$SIN_RED"
igual "sin red, la de respaldo" "$(version_node_a_instalar)" "24.9.9"
VERSION_NODE_RESPALDO="24.30.0"
URL_NODE_DIST="$CON_RED"
igual "index.json más viejo que el respaldo, el respaldo" "$(version_node_a_instalar)" "24.30.0"

VERSION_NODE_RESPALDO="$RESPALDO_REAL"
URL_NODE_DIST="$SIN_RED"
igual "sin red, el respaldo de verdad" "$(version_node_a_instalar)" "24.22.1"
igual "huella fijada (arm64) = SHASUMS256.txt oficial" "$(huella_node 24.22.1 node-v24.22.1-darwin-arm64.tar.gz)" \
    "$(awk '$2 == "node-v24.22.1-darwin-arm64.tar.gz" { print $1 }' "$fixtures/v24.22.1/SHASUMS256.txt")"
igual "huella fijada (x64) = SHASUMS256.txt oficial" "$(huella_node 24.22.1 node-v24.22.1-darwin-x64.tar.gz)" \
    "$(awk '$2 == "node-v24.22.1-darwin-x64.tar.gz" { print $1 }' "$fixtures/v24.22.1/SHASUMS256.txt")"

VERSION_NODE_RESPALDO="24.9.9"
URL_NODE_DIST="$CON_RED"
igual "huella de otra versión, de su SHASUMS256.txt" "$(huella_node 24.22.1 node-v24.22.1-darwin-x64.tar.gz)" \
    "d132557e7ee2b85af08b0c8c34338e65c6430f2238d01f727728ef42dc83b035"
igual "fichero que no está en SHASUMS256.txt" "$(huella_node 24.22.1 node-v24.22.1-darwin-arm64.tar.xz)" ""
URL_NODE_DIST="$SIN_RED"
igual "sin red y sin huella fijada, nada" "$(huella_node 24.22.1 node-v24.22.1-darwin-x64.tar.gz)" ""

# Orden del PATH. En Mac, path_helper (/etc/zprofile) y Homebrew mandan detrás lo que .zshenv puso delante: con
# otro Node en /usr/local/bin u /opt/homebrew/bin, ese ganaba al de Drazo y el aviso de Node no se iba nunca.
cuenta() { printf '%s' ":$1:" | awk -v d=":$2:" '{ n = 0; while ((i = index($0, d)) > 0) { n++; $0 = substr($0, i + 1) } print n }'; }
tmp="$(mktemp -d)"
casa="$tmp/casa"
datos="$casa/.local/share/drazo"
mkdir -p "$datos/uv" "$datos/nodejs/bin" "$datos/ffmpeg" "$tmp/viejo"
printf '#!/bin/sh\necho drazo\n' > "$datos/nodejs/bin/node"
printf '#!/bin/sh\necho viejo\n' > "$tmp/viejo/node"
chmod +x "$datos/nodejs/bin/node" "$tmp/viejo/node"
# El entorno.sh que escribe de verdad asegurar_entorno (instalar.sh), sacado tal cual de su heredoc
awk '/<<.ENTORNO.$/ { dentro = 1; next } /^ENTORNO$/ { dentro = 0 } dentro' "$raiz/instalar.sh" > "$datos/entorno.sh"
igual "instalar.sh escribe entorno.sh" "$(grep -c 'nodejs/bin' "$datos/entorno.sh")" "1"
# Como queda tras path_helper: el Node viejo y el sistema delante, la carpeta de Drazo al final
tras_path_helper="$tmp/viejo:$PATH:$datos/nodejs/bin:$datos/uv"
for sh_prueba in bash sh dash zsh; do
    command -v "$sh_prueba" >/dev/null 2>&1 || { echo "salto $sh_prueba (no está)"; continue; }
    salida="$(HOME="$casa" PATH="$tras_path_helper" "$sh_prueba" -c '. "$HOME/.local/share/drazo/entorno.sh"; . "$HOME/.local/share/drazo/entorno.sh"; printf "%s\n%s\n" "$(node)" "$PATH"')"
    ruta="$(printf '%s\n' "$salida" | sed -n 2p)"
    igual "$sh_prueba: tras path_helper, node es el de Drazo" "$(printf '%s\n' "$salida" | sed -n 1p)" "drazo"
    igual "$sh_prueba: las tres carpetas de Drazo, delante" "${ruta%%:$tmp/viejo:*}" "$datos/ffmpeg:$datos/nodejs/bin:$datos/uv"
    igual "$sh_prueba: cargado dos veces, nodejs/bin sale una sola vez" "$(cuenta "$ruta" "$datos/nodejs/bin")" "1"
    igual "$sh_prueba: no se pierde nada del PATH" "${ruta#*:$tmp/viejo:}" "$PATH"
done
# cargar_rutas_drazo, en el proceso del instalador, hace lo mismo
salida="$(DRAZO_FFMPEG="$datos/ffmpeg" DRAZO_NODEJS="$datos/nodejs" DRAZO_UV="$datos/uv" PATH="$tras_path_helper" bash -c '. "$1"; DRAZO_FFMPEG="$2/ffmpeg"; DRAZO_NODEJS="$2/nodejs"; DRAZO_UV="$2/uv"; cargar_rutas_drazo; cargar_rutas_drazo; printf "%s\n%s\n" "$(node)" "$PATH"' _ "$raiz/plugins/drazo/scripts/drazo-comun.sh" "$datos")"
igual "cargar_rutas_drazo: node es el de Drazo" "$(printf '%s\n' "$salida" | sed -n 1p)" "drazo"
igual "cargar_rutas_drazo: nodejs/bin una sola vez" "$(cuenta "$(printf '%s\n' "$salida" | sed -n 2p)" "$datos/nodejs/bin")" "1"
# Sin la carpeta de Drazo, entorno.sh no añade nada
salida="$(HOME="$tmp/otra" PATH="/usr/bin:/bin" sh -c '. "$1"; printf "%s" "$PATH"' _ "$datos/entorno.sh")"
igual "sin carpetas de Drazo, el PATH no cambia" "$salida" "/usr/bin:/bin"
rm -rf "$tmp"

echo ""
if [ "$fallos" -eq 0 ]; then echo "Todas las pruebas pasan."; exit 0; fi
echo "$fallos pruebas fallan."
exit 1
