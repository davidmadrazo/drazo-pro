# Comprobaciones de Drazo Pro en macOS, compartidas por el instalador y el doctor.
# Se carga con: . "<carpeta>/drazo-comun.sh"
# Compatible con el bash 3.2 de macOS: sin arrays asociativos ni ${var,,}.

DRAZO_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRAZO_DATOS="$HOME/.local/share/drazo"
DRAZO_VENV="$DRAZO_DATOS/venv"
DRAZO_PYTHON="$DRAZO_VENV/bin/python"
DRAZO_NODE="$DRAZO_DATOS/node"
DRAZO_ENTORNO="$DRAZO_DATOS/entorno.sh"
REQUISITOS_PYTHON="$DRAZO_SCRIPTS/requisitos-python.txt"
LISTA_FUENTES="$DRAZO_SCRIPTS/fuentes.txt"
CARPETA_FUENTES="$HOME/Library/Fonts"
VERSION_TESSERACT="0.2.0"
SHA256_TESSERACT_ARM64="c5a0ab2d7840a3bfee60270d8f9b365f4e5ce8833142bbf9a42beea3d5419ca0"
SHA256_TESSERACT_X86_64="15d33a41a90d62d5bcaffcab0410c732fbd77ee029a8d31e2541012e27a46a8b"
TSRCT_RUTA="$HOME/Library/Application Support/Tesseract/bin/tsrct"
SKILLS_TESSERACT="tesseract-video tesseract-motion"
ID_PLUGIN="drazo@drazo"
NODE_MINIMO=22
DISCO_MINIMO_GB=10
COMPROBACIONES_DRAZO="sistema brew git node claude cuenta ffmpeg python venv playwright chrome navegador skills fuentes telemetria tesseract licencia bash plugin disco memoria"

if [ -t 1 ]; then
    C_VERDE=$'\033[32m'; C_ROJO=$'\033[31m'; C_AMARILLO=$'\033[33m'; C_CIAN=$'\033[36m'; C_FIN=$'\033[0m'
else
    C_VERDE=""; C_ROJO=""; C_AMARILLO=""; C_CIAN=""; C_FIN=""
fi

# Resultado de la última comprobación (bash 3.2 no tiene objetos: variables globales y arrays paralelos).
RES_ID=""; RES_NOMBRE=""; RES_ESTADO=""; RES_DETALLE=""; RES_ARREGLO=""; RES_OPCIONAL=0
L_NOMBRE=(); L_ESTADO=(); L_ARREGLO=(); L_OPCIONAL=()

resultado() {
    RES_ID="$1"; RES_NOMBRE="$2"; RES_ESTADO="$3"; RES_DETALLE="$4"; RES_ARREGLO="${5:-}"; RES_OPCIONAL="${6:-0}"
}

mostrar_resultado() {
    local color etiqueta relleno
    case "$RES_ESTADO" in
        ok) color="$C_VERDE"; etiqueta="  OK  " ;;
        falta) color="$C_ROJO"; etiqueta="FALTA " ;;
        *) color="$C_AMARILLO"; etiqueta="AVISO " ;;
    esac
    # printf rellena por bytes y las tildes ocupan dos: se rellena contando caracteres.
    relleno=$((40 - ${#RES_NOMBRE}))
    [ "$relleno" -lt 1 ] && relleno=1
    printf '  %s[%s]%s %s%*s%s\n' "$color" "$etiqueta" "$C_FIN" "$RES_NOMBRE" "$relleno" "" "$RES_DETALLE"
}

registrar() {
    L_NOMBRE+=("$RES_NOMBRE"); L_ESTADO+=("$RES_ESTADO"); L_ARREGLO+=("$RES_ARREGLO"); L_OPCIONAL+=("$RES_OPCIONAL")
}

# Lista final: lo que falta (obligatorio) con su arreglo, y los avisos aparte.
mostrar_arreglos() {
    local i n=1 hay_avisos=0 faltan=0
    echo ""
    for i in "${!L_ESTADO[@]}"; do [ "${L_ESTADO[$i]}" = "falta" ] && faltan=$((faltan + 1)); done
    if [ "$faltan" -eq 0 ]; then
        echo "${C_VERDE}Todo lo necesario está listo.${C_FIN}"
    else
        echo "${C_ROJO}Qué falta y cómo arreglarlo:${C_FIN}"
        for i in "${!L_ESTADO[@]}"; do
            [ "${L_ESTADO[$i]}" = "falta" ] || continue
            echo "  $n. Falta ${L_NOMBRE[$i]}: ${L_ARREGLO[$i]}"
            n=$((n + 1))
        done
    fi
    for i in "${!L_ESTADO[@]}"; do
        [ "${L_ESTADO[$i]}" = "aviso" ] && [ -n "${L_ARREGLO[$i]}" ] || continue
        [ "$hay_avisos" -eq 0 ] && { echo ""; echo "${C_AMARILLO}Avisos:${C_FIN}"; hay_avisos=1; }
        echo "  - ${L_NOMBRE[$i]}: ${L_ARREGLO[$i]}"
    done
}

hay_faltas_obligatorias() {
    local i
    for i in "${!L_ESTADO[@]}"; do
        [ "${L_ESTADO[$i]}" = "falta" ] && [ "${L_OPCIONAL[$i]}" != "1" ] && return 0
    done
    return 1
}

# Primer número con forma x.y[.z] del texto.
leer_version() {
    printf '%s\n' "$1" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1
}

# 0 si la versión $1 es >= $2 (comparación numérica por partes).
version_minima() {
    local a b i
    IFS=. read -r -a a <<< "$1"; IFS=. read -r -a b <<< "$2"
    for i in 0 1 2; do
        if [ "${a[$i]:-0}" -gt "${b[$i]:-0}" ] 2>/dev/null; then return 0; fi
        if [ "${a[$i]:-0}" -lt "${b[$i]:-0}" ] 2>/dev/null; then return 1; fi
    done
    return 0
}

# Sin las herramientas de línea de órdenes de Xcode, /usr/bin/git y /usr/bin/python3 abren
# un diálogo de instalación al ejecutarlos: no se tocan si no están instaladas.
tiene_clt() { xcode-select -p >/dev/null 2>&1; }

ruta_brew() {
    if command -v brew >/dev/null 2>&1; then command -v brew; return; fi
    local b
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && { echo "$b"; return; }; done
}

# Deja brew (y lo que instala) en el PATH de este proceso.
cargar_brew() {
    local b; b="$(ruta_brew)"
    [ -n "$b" ] && eval "$("$b" shellenv)"
}

carpeta_config_claude() { echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; }

ruta_claude() {
    if command -v claude >/dev/null 2>&1; then command -v claude; return; fi
    [ -x "$HOME/.local/bin/claude" ] && echo "$HOME/.local/bin/claude"
}

# Evalúa una expresión JS sobre el JSON que entra por stdin (d). macOS no siempre trae jq.
# Imprime vacío si no hay Node o el JSON no se puede leer.
json_eval() {
    command -v node >/dev/null 2>&1 || return 0
    node -e '
let s = ""
process.stdin.on("data", (c) => (s += c)).on("end", () => {
  const i = s.search(/[\[{]/), j = Math.max(s.lastIndexOf("]"), s.lastIndexOf("}"))
  let d = null
  try { d = JSON.parse(s.slice(i, j + 1)) } catch {}
  let r = ""
  try { r = new Function("d", "return (" + process.argv[1] + ")")(d) } catch {}
  process.stdout.write(r === undefined || r === null ? "" : String(r))
})' "$1" 2>/dev/null
}

# Valor guardado en el entorno de Drazo (entorno.sh), que carga el perfil de la terminal.
valor_entorno() {
    [ -f "$DRAZO_ENTORNO" ] || return 0
    sed -n "s/^export $1='\(.*\)'\$/\1/p" "$DRAZO_ENTORNO" | tail -n 1
}

# Python de base para crear el entorno de Drazo (se descartan los de conda).
PY_BASE_EXE=""; PY_BASE_VERSION=""
buscar_python_base() {
    local c exe salida version conda orden mejor_orden=99 brew prefijo=""
    PY_BASE_EXE=""; PY_BASE_VERSION=""
    brew="$(ruta_brew)"
    [ -n "$brew" ] && prefijo="$(dirname "$(dirname "$brew")")"
    for c in python3.12 python3.13 python3.11 python3.14 python3.10 python3; do
        exe="$(command -v "$c" 2>/dev/null)"
        if [ -z "$exe" ] && [ -n "$prefijo" ] && [ -x "$prefijo/bin/$c" ]; then exe="$prefijo/bin/$c"; fi
        [ -n "$exe" ] || continue
        if [ "$exe" = "/usr/bin/python3" ] && ! tiene_clt; then continue; fi
        salida="$("$exe" -c 'import os,sys; print("%d.%d.%d" % sys.version_info[:3]); print(sys.executable); print(os.path.isdir(os.path.join(sys.prefix, "conda-meta")))' 2>/dev/null)" || continue
        version="$(printf '%s\n' "$salida" | sed -n 1p)"
        conda="$(printf '%s\n' "$salida" | sed -n 3p)"
        [ "$conda" = "True" ] && continue
        version_minima "$version" "3.10" || continue
        case "$version" in 3.12.*) orden=0 ;; 3.13.*) orden=1 ;; 3.11.*) orden=2 ;; 3.14.*) orden=3 ;; 3.10.*) orden=4 ;; *) orden=5 ;; esac
        if [ "$orden" -lt "$mejor_orden" ]; then
            mejor_orden="$orden"; PY_BASE_VERSION="$version"; PY_BASE_EXE="$(printf '%s\n' "$salida" | sed -n 2p)"
        fi
    done
}

ruta_chrome() {
    local a
    for a in "/Applications/Google Chrome.app" "$HOME/Applications/Google Chrome.app"; do
        if [ -x "$a/Contents/MacOS/Google Chrome" ]; then echo "$a"; return; fi
    done
}

# El navegador que usa HyperFrames para renderizar (chrome-headless-shell en su caché).
ruta_navegador_hf() {
    if [ -n "$HYPERFRAMES_BROWSER_PATH" ] && [ -x "$HYPERFRAMES_BROWSER_PATH" ]; then echo "$HYPERFRAMES_BROWSER_PATH"; return; fi
    local raiz exe
    for raiz in "$HOME/.cache/hyperframes/chrome/chrome-headless-shell" "$HOME/.cache/puppeteer/chrome-headless-shell"; do
        for exe in "$raiz"/*/chrome-headless-shell-mac-*/chrome-headless-shell; do
            if [ -x "$exe" ]; then echo "$exe"; return; fi
        done
    done
}

familias_fuentes() { grep -v -e '^#' -e '^commit|' -e '^$' "$LISTA_FUENTES" | cut -d'|' -f1 | uniq; }

# Una familia cuenta como instalada si hay algún fichero suyo en las carpetas de fuentes.
familia_instalada() {
    local prefijo d f
    prefijo="$(printf '%s' "$1" | tr -d ' ')"
    for d in "$HOME/Library/Fonts" /Library/Fonts /System/Library/Fonts /System/Library/Fonts/Supplemental; do
        for f in "$d/$prefijo"*; do
            if [ -e "$f" ]; then return 0; fi
        done
    done
    return 1
}

comprobar_sistema() {
    local nombre="macOS 13 o superior" v arq
    if [ "$(uname -s)" != "Darwin" ]; then resultado sistema "$nombre" falta "$(uname -s)" "Esto es para macOS; en Windows usa instalar.ps1."; return; fi
    v="$(sw_vers -productVersion 2>/dev/null)"
    arq="$(uname -m)"
    [ "$(sysctl -in sysctl.proc_translated 2>/dev/null)" = "1" ] && arq="arm64"
    if ! version_minima "$v" "13.0"; then resultado sistema "$nombre" falta "macOS $v" "Drazo necesita macOS 13 (Ventura) o superior."; return; fi
    resultado sistema "$nombre" ok "macOS $v ($arq)"
}

comprobar_brew() {
    local b; b="$(ruta_brew)"
    if [ -z "$b" ]; then resultado brew "Homebrew" falta "no está" "Instálalo desde https://brew.sh (el instalador de Drazo lo hace por ti)."; return; fi
    if ! command -v brew >/dev/null 2>&1; then
        resultado brew "Homebrew" falta "instalado en $b, pero esta terminal no lo carga" "Vuelve a ejecutar el instalador de Drazo (lo añade al entorno) y abre una terminal nueva."; return
    fi
    resultado brew "Homebrew" ok "$(leer_version "$("$b" --version 2>/dev/null | head -n 1)")"
}

comprobar_git() {
    local g; g="$(command -v git 2>/dev/null)"
    if [ -z "$g" ] || { [ "$g" = "/usr/bin/git" ] && ! tiene_clt; }; then
        resultado git "Git" falta "no está" "xcode-select --install (o brew install git)"; return
    fi
    resultado git "Git" ok "$(leer_version "$("$g" --version 2>/dev/null)")"
}

comprobar_node() {
    local nombre="Node.js 22 o superior" v
    if ! command -v node >/dev/null 2>&1; then resultado node "$nombre" falta "no está" "brew install node"; return; fi
    v="$(leer_version "$(node --version 2>/dev/null)")"
    if ! version_minima "$v" "$NODE_MINIMO"; then resultado node "$nombre" falta "versión $v" "brew install node (o brew upgrade node)"; return; fi
    if ! command -v npm >/dev/null 2>&1; then resultado node "$nombre" falta "$v sin npm" "brew reinstall node"; return; fi
    resultado node "$nombre" ok "$v"
}

comprobar_claude() {
    local c; c="$(ruta_claude)"
    if [ -z "$c" ]; then resultado claude "Claude Code" falta "no está" "curl -fsSL https://claude.ai/install.sh | bash"; return; fi
    resultado claude "Claude Code" ok "$(leer_version "$("$c" --version 2>/dev/null)")"
}

comprobar_cuenta() {
    local nombre="Cuenta de Claude Max (5x o superior)" c json sesion plan
    c="$(ruta_claude)"
    if [ -z "$c" ]; then resultado cuenta "$nombre" falta "sin Claude Code" "Instala Claude Code y entra con tu cuenta de Claude Max."; return; fi
    json="$("$c" auth status --json 2>/dev/null)"
    if [ -z "$json" ]; then resultado cuenta "$nombre" aviso "no se pudo leer" "Abre una terminal, escribe claude y entra con tu cuenta de Claude Max."; return; fi
    sesion="$(printf '%s' "$json" | json_eval 'd && d.loggedIn')"
    plan="$(printf '%s' "$json" | json_eval 'd && d.subscriptionType')"
    if [ -z "$sesion" ]; then
        printf '%s' "$json" | grep -q '"loggedIn": *true' && sesion="true"
        plan="$(printf '%s' "$json" | sed -n 's/.*"subscriptionType": *"\([^"]*\)".*/\1/p' | head -n 1)"
    fi
    if [ "$sesion" != "true" ]; then resultado cuenta "$nombre" falta "sin sesión iniciada" "Abre una terminal, escribe claude y entra con tu cuenta de Claude Max (5x o superior)."; return; fi
    case "$plan" in
        max) resultado cuenta "$nombre" ok "sesión iniciada con Claude Max" ;;
        pro) resultado cuenta "$nombre" falta "plan Pro" "Drazo Pro necesita Claude Max 5x o superior: con Pro se queda corto. Cambia de plan en claude.ai." ;;
        *) resultado cuenta "$nombre" aviso "plan «$plan»" "Drazo Pro está pensado para Claude Max 5x o superior." ;;
    esac
}

comprobar_ffmpeg() {
    local nombre="ffmpeg con libx264 y zscale" f completo="" brew primera faltan=""
    brew="$(ruta_brew)"
    [ -n "$brew" ] && completo="$(dirname "$(dirname "$brew")")/opt/ffmpeg-full/bin/ffmpeg"
    f="$(command -v ffmpeg 2>/dev/null)"
    if [ -z "$f" ]; then
        if [ -n "$completo" ] && [ -x "$completo" ]; then resultado ffmpeg "$nombre" falta "ffmpeg-full instalado, pero fuera del PATH" "Abre una terminal nueva: el entorno de Drazo lo pone el primero."; return; fi
        resultado ffmpeg "$nombre" falta "no está" "brew install ffmpeg-full"; return
    fi
    primera="$("$f" -hide_banner -version 2>/dev/null | head -n 1 | sed 's/^ffmpeg version //; s/ Copyright.*//')"
    "$f" -hide_banner -version 2>/dev/null | grep -q -- '--enable-libx264' || faltan="libx264"
    "$f" -hide_banner -filters 2>/dev/null | grep -q ' zscale ' || faltan="${faltan:+$faltan, }zscale"
    command -v ffprobe >/dev/null 2>&1 || faltan="${faltan:+$faltan, }ffprobe"
    if [ -n "$faltan" ]; then
        if [ -n "$completo" ] && [ -x "$completo" ] && [ "$f" != "$completo" ]; then
            resultado ffmpeg "$nombre" falta "$primera sin $faltan ($f)" "ffmpeg-full ya está instalado: abre una terminal nueva para que vaya el primero."; return
        fi
        resultado ffmpeg "$nombre" falta "$primera sin $faltan ($f)" "brew install ffmpeg-full (el ffmpeg normal de Homebrew no trae zscale)"; return
    fi
    resultado ffmpeg "$nombre" ok "$primera"
}

comprobar_python() {
    local nombre="Python 3.10 o superior"
    buscar_python_base
    if [ -n "$PY_BASE_EXE" ]; then resultado python "$nombre" ok "$PY_BASE_VERSION ($PY_BASE_EXE)"; return; fi
    if [ -x "$DRAZO_PYTHON" ]; then resultado python "$nombre" aviso "no hay Python en el sistema, pero el entorno de Drazo existe" "Solo hace falta para rehacer el entorno: brew install python@3.12"; return; fi
    resultado python "$nombre" falta "no está (los de conda no sirven)" "brew install python@3.12"
}

comprobar_venv() {
    local nombre="Entorno de Python de Drazo" salida version mal bien
    if [ ! -x "$DRAZO_PYTHON" ]; then resultado venv "$nombre" falta "no existe $DRAZO_VENV" "Lo crea el instalador de Drazo."; return; fi
    salida="$("$DRAZO_PYTHON" -X utf8 "$DRAZO_SCRIPTS/comprobar-python.py" 2>/dev/null)"
    version="$(printf '%s\n' "$salida" | awk '$1 == "PYTHON" { print $2; exit }')"
    if [ -z "$version" ]; then resultado venv "$nombre" falta "su Python no arranca" "Vuelve a ejecutar el instalador de Drazo: rehace el entorno."; return; fi
    mal="$(printf '%s\n' "$salida" | awk '$1 == "MAL" { printf "%s%s", s, $2; s = ", " }')"
    bien="$(printf '%s\n' "$salida" | awk '$1 == "OK" { printf "%s%s %s", s, $2, $3; s = ", " }')"
    if [ -n "$mal" ]; then resultado venv "$nombre" falta "Python $version; fallan: $mal" "Vuelve a ejecutar el instalador de Drazo: reinstala los paquetes."; return; fi
    resultado venv "$nombre" ok "Python $version · $bien"
}

comprobar_playwright() {
    local nombre="playwright-core de Drazo" pj="$DRAZO_NODE/node_modules/playwright-core/package.json"
    if [ ! -f "$pj" ]; then resultado playwright "$nombre" falta "no está en $DRAZO_NODE" "Lo instala el instalador de Drazo (solo para Drazo, no global)."; return; fi
    resultado playwright "$nombre" ok "$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$pj" | head -n 1)"
}

comprobar_chrome() {
    local app; app="$(ruta_chrome)"
    if [ -z "$app" ]; then resultado chrome "Google Chrome" falta "no está" "brew install --cask google-chrome (o descárgalo de google.com/chrome)"; return; fi
    resultado chrome "Google Chrome" ok "$(defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null)"
}

comprobar_navegador() {
    local exe; exe="$(ruta_navegador_hf)"
    if [ -z "$exe" ]; then resultado navegador "Navegador de HyperFrames" falta "no está" "npx hyperframes browser ensure"; return; fi
    resultado navegador "Navegador de HyperFrames" ok "chrome-headless-shell $(leer_version "${exe#"$HOME"}")"
}

comprobar_skills() {
    local nombre="Skills públicas de HyperFrames" dir n
    dir="$(carpeta_config_claude)/skills"
    if [ ! -f "$dir/hyperframes/SKILL.md" ]; then resultado skills "$nombre" falta "no están en $dir" "npx skills add heygen-com/hyperframes -g -a claude-code"; return; fi
    n="$(ls -d "$dir"/hyperframes* 2>/dev/null | wc -l | tr -d ' ')"
    resultado skills "$nombre" ok "$n skills hyperframes* en $dir"
}

comprobar_fuentes() {
    local fam faltan=""
    while IFS= read -r fam; do
        [ -n "$fam" ] || continue
        familia_instalada "$fam" || faltan="${faltan:+$faltan, }$fam"
    done <<< "$(familias_fuentes)"
    if [ -n "$faltan" ]; then resultado fuentes "Fuentes de las plantillas" falta "faltan: $faltan" "Las instala el instalador de Drazo (Google Fonts, licencia OFL)."; return; fi
    resultado fuentes "Fuentes de las plantillas" ok "Anton, Caveat, Poppins, Inter y JetBrains Mono"
}

comprobar_telemetria() {
    local nombre="Telemetría de HyperFrames apagada" v
    v="${HYPERFRAMES_NO_TELEMETRY:-$(valor_entorno HYPERFRAMES_NO_TELEMETRY)}"
    if [ "$v" = "1" ]; then resultado telemetria "$nombre" ok "HYPERFRAMES_NO_TELEMETRY=1"; return; fi
    resultado telemetria "$nombre" falta "sin HYPERFRAMES_NO_TELEMETRY=1" "La pone el instalador de Drazo (en el entorno de Drazo)."
}

comprobar_tesseract() {
    local nombre="Tesseract $VERSION_TESSERACT (opcional)" v dir s sin="" pin
    if [ ! -x "$TSRCT_RUTA" ]; then resultado tesseract "$nombre" aviso "no instalado" "Opcional: el instalador de Drazo lo instala si aceptas las condiciones de Mirage." 1; return; fi
    v="$(leer_version "$("$TSRCT_RUTA" --version 2>/dev/null)")"
    dir="$(carpeta_config_claude)/skills"
    for s in $SKILLS_TESSERACT; do [ -f "$dir/$s/SKILL.md" ] || sin="${sin:+$sin, }$s"; done
    pin="$(head -n 1 "$dir/tesseract-video/references/cli-version.txt" 2>/dev/null | tr -d '[:space:]')"
    if [ "$v" != "$VERSION_TESSERACT" ]; then resultado tesseract "$nombre" aviso "tsrct $v (Drazo usa $VERSION_TESSERACT)" "Reinstala Tesseract con el instalador de Drazo." 1; return; fi
    if [ -n "$sin" ]; then resultado tesseract "$nombre" aviso "tsrct $v; faltan las skills $sin" "Vuelve a ejecutar el instalador de Drazo y acepta Tesseract." 1; return; fi
    if [ -n "$pin" ] && [ "$pin" != "$VERSION_TESSERACT" ]; then resultado tesseract "$nombre" aviso "tsrct $v, pero sus skills piden $pin" "Vuelve a ejecutar el instalador de Drazo para alinear las skills de Tesseract." 1; return; fi
    resultado tesseract "$nombre" ok "tsrct $v y sus skills" 1
}

comprobar_licencia() {
    local nombre="Clave de licencia (DRAZO_LICENCIA)" guardada clave visible
    guardada="$(valor_entorno DRAZO_LICENCIA)"
    clave="${DRAZO_LICENCIA:-$guardada}"
    if [ -z "$clave" ]; then resultado licencia "$nombre" falta "no está" "Vuelve a ejecutar el instalador de Drazo y pega tu clave (empieza por drz_)."; return; fi
    visible="drz_…${clave: -4}"
    case "$clave" in drz_*) ;; *) resultado licencia "$nombre" aviso "no empieza por drz_" "Revisa que pegaste la clave completa de Drazo."; return ;; esac
    if [ -z "$DRAZO_LICENCIA" ]; then resultado licencia "$nombre" aviso "$visible guardada, pero esta terminal no la ve" "Abre una terminal nueva y abre Claude Code desde ella."; return; fi
    resultado licencia "$nombre" ok "$visible"
}

# Los motores de Drazo se descargan con un comando bash (curl ... | node ...) que lee $DRAZO_LICENCIA.
# La Bash de Claude Code no hereda las variables de ~/.zshrc, pero zsh lee ~/.zshenv siempre:
# se mira esta sesión y también un zsh limpio, que es lo que verá Claude Code al abrirse.
comprobar_bash() {
    local nombre="Terminal Bash de Claude Code" salida limpio="" faltan=""
    salida="$(bash -c 'command -v curl >/dev/null && echo curl=si || echo curl=no; command -v node >/dev/null && echo node=si || echo node=no; [ ${#DRAZO_LICENCIA} -gt 0 ] && echo clave=si || echo clave=no' 2>/dev/null)"
    case "$salida" in *curl=si*) ;; *) faltan="curl" ;; esac
    case "$salida" in *node=si*) ;; *) faltan="${faltan:+$faltan, }node" ;; esac
    if [ -n "$faltan" ]; then resultado bash "$nombre" falta "bash no encuentra: $faltan" "Vuelve a ejecutar el instalador de Drazo y abre una terminal nueva."; return; fi
    if [ -x /bin/zsh ]; then
        limpio="$(env -i HOME="$HOME" /bin/zsh -c '[ ${#DRAZO_LICENCIA} -gt 0 ] && echo clave=si || echo clave=no' 2>/dev/null)"
    fi
    case "$salida" in
        *clave=si*)
            if [ "$limpio" = "clave=no" ]; then
                resultado bash "$nombre" aviso "esta sesión ve la clave, pero un zsh nuevo no la carga" "Vuelve a ejecutar el instalador de Drazo: deja la clave en ~/.zshenv para que la vea siempre."; return
            fi
            resultado bash "$nombre" ok "curl, node y la clave DRAZO_LICENCIA visibles" ;;
        *)
            if [ "$limpio" = "clave=si" ]; then
                resultado bash "$nombre" falta "la clave está guardada, pero esta sesión no la ve" "Cierra Claude Code y la terminal, abre una terminal nueva y vuelve a escribir claude."
            else
                resultado bash "$nombre" falta "la clave DRAZO_LICENCIA no se ve desde bash" "Pon tu clave con el instalador de Drazo y abre Claude Code desde una terminal nueva."
            fi ;;
    esac
}

comprobar_plugin() {
    local nombre="Plugin drazo en Claude Code" c json fila activo version ambito errores
    c="$(ruta_claude)"
    if [ -z "$c" ]; then resultado plugin "$nombre" falta "sin Claude Code" "Instala Claude Code y vuelve a ejecutar el instalador de Drazo."; return; fi
    json="$("$c" plugin list --json 2>/dev/null)"
    fila="$(printf '%s' "$json" | ID_PLUGIN="$ID_PLUGIN" json_eval '(Array.isArray(d) ? d : []).filter((p) => p.id === process.env.ID_PLUGIN).map((p) => [p.enabled, p.version, p.scope, (p.errors || []).join("; ")].join("|"))[0] || ""')"
    if [ -z "$fila" ]; then
        if ! command -v node >/dev/null 2>&1 && printf '%s' "$json" | grep -q "\"$ID_PLUGIN\""; then
            resultado plugin "$nombre" ok "instalado (sin Node no se ve el detalle)"; return
        fi
        resultado plugin "$nombre" falta "no instalado" "Lo instala el instalador de Drazo (claude plugin install drazo@drazo)."; return
    fi
    IFS='|' read -r activo version ambito errores <<< "$fila"
    if [ -n "$errores" ]; then resultado plugin "$nombre" falta "con errores: $errores" "Vuelve a ejecutar el instalador de Drazo; si sigue, escribe al soporte."; return; fi
    if [ "$activo" != "true" ]; then resultado plugin "$nombre" falta "$version desactivado" "Actívalo: claude plugin enable drazo@drazo"; return; fi
    resultado plugin "$nombre" ok "versión $version, ámbito $ambito"
}

comprobar_disco() {
    local nombre="Espacio libre (más de $DISCO_MINIMO_GB GB)" kb gb
    kb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR == 2 { print $4 }')"
    gb=$(( ${kb:-0} / 1048576 ))
    if [ "$gb" -lt "$DISCO_MINIMO_GB" ]; then resultado disco "$nombre" falta "$gb GB libres" "Libera espacio: brutos, entorno de Python, navegador y renders ocupan varios GB."; return; fi
    resultado disco "$nombre" ok "$gb GB libres"
}

comprobar_memoria() {
    local nombre="Memoria (RAM)" total pagina paginas gb libre
    total="$(sysctl -n hw.memsize 2>/dev/null)"
    if [ -z "$total" ]; then resultado memoria "$nombre" aviso "no se pudo leer"; return; fi
    pagina="$(sysctl -n hw.pagesize 2>/dev/null)"
    paginas="$(vm_stat 2>/dev/null | awk '/Pages (free|inactive|speculative)/ { gsub(/\./, "", $NF); s += $NF } END { print s + 0 }')"
    gb=$(( total / 1073741824 )); libre=$(( paginas * ${pagina:-4096} / 1073741824 ))
    if [ "$gb" -lt 8 ]; then resultado memoria "$nombre" aviso "$gb GB en total, $libre GB libres ahora" "Con menos de 8 GB los renders van lentos o fallan: cierra otras aplicaciones al editar."; return; fi
    resultado memoria "$nombre" ok "$gb GB en total, $libre GB libres ahora"
}

# Ejecuta la comprobación $1, la muestra y la apunta para el resumen final.
comprobar() {
    "comprobar_$1"
    mostrar_resultado
    registrar
}
