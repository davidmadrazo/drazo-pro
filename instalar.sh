#!/bin/bash
# Instalador de Drazo Pro para macOS.
# Comprueba cada requisito y, si falta, lo instala pidiendo permiso en cada paso. Al final pasa el doctor.
# Uso:
#   bash instalar.sh                              instala lo que falte
#   bash instalar.sh --solo-comprobar             solo mira, no cambia nada
#   bash instalar.sh --marketplace <ruta o repo>  otra fuente para el marketplace (para pruebas)

# Repo de GitHub con el marketplace y el plugin de Drazo (aún no publicado).
REPO_DRAZO="davidmadrazo/drazo-pro"
RAMA_DRAZO="main"
URL_BASE_DRAZO="https://raw.githubusercontent.com/$REPO_DRAZO/$RAMA_DRAZO"

SOLO_COMPROBAR=0
MARKETPLACE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --solo-comprobar) SOLO_COMPROBAR=1 ;;
        --marketplace) MARKETPLACE="$2"; shift ;;
        *) echo "Opción desconocida: $1 (usa --solo-comprobar o --marketplace <fuente>)"; exit 2 ;;
    esac
    shift
done

FICHEROS_PLUGIN=".mcp.json scripts/drazo-comun.sh scripts/drazo-doctor.sh scripts/comprobar-servidor.mjs scripts/comprobar-python.py scripts/requisitos-python.txt scripts/fuentes.txt"
CARPETA_TEMPORAL=""
PLUGIN=""
trap '[ -n "$CARPETA_TEMPORAL" ] && rm -rf "$CARPETA_TEMPORAL"' EXIT

# Desde una copia del repo usa sus ficheros; si el instalador llega suelto, baja los que necesita.
preparar_plugin() {
    local yo="${BASH_SOURCE[0]}" f
    if [ -n "$yo" ] && [ -f "$yo" ] && [ -f "$(dirname "$yo")/plugins/drazo/scripts/drazo-comun.sh" ]; then
        PLUGIN="$(cd "$(dirname "$yo")/plugins/drazo" && pwd)"
        return 0
    fi
    CARPETA_TEMPORAL="$(mktemp -d "${TMPDIR:-/tmp}/drazo-instalador.XXXXXX")" || return 1
    PLUGIN="$CARPETA_TEMPORAL/plugin"
    for f in $FICHEROS_PLUGIN; do
        mkdir -p "$PLUGIN/$(dirname "$f")"
        if ! curl -fsSL "$URL_BASE_DRAZO/plugins/drazo/$f" -o "$PLUGIN/$f"; then
            echo "No pude descargar $f desde $URL_BASE_DRAZO"
            return 1
        fi
    done
}

# Las respuestas se leen de la terminal aunque el script llegue por una tubería (curl | bash).
preguntar() {
    local defecto="${2:-s}" sufijo="[S/n]" r
    [ "$defecto" = "n" ] && sufijo="[s/N]"
    while true; do
        printf '%s %s ' "$1" "$sufijo" > /dev/tty
        IFS= read -r r < /dev/tty || r=""
        r="$(printf '%s' "$r" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
        case "$r" in
            "") [ "$defecto" = "s" ]; return ;;
            s|si|sí|y|yes) return 0 ;;
            n|no) return 1 ;;
        esac
    done
}

paso() { echo ""; echo "${C_CIAN}== $1${C_FIN}"; }

requiere_brew() {
    command -v brew >/dev/null 2>&1 && return 0
    echo "${C_ROJO}Falta Homebrew: no puedo seguir con este paso.${C_FIN}"
    return 1
}

requiere_node() {
    command -v npm >/dev/null 2>&1 && return 0
    echo "${C_ROJO}Falta Node.js: no puedo seguir con este paso.${C_FIN}"
    return 1
}

# El entorno de Drazo (clave, telemetría, rutas) vive en entorno.sh, que solo tiene exports.
# ~/.zshenv lo lee todo zsh, también la Bash de Claude Code (que no hereda lo de ~/.zshrc);
# ~/.zshrc lo vuelve a cargar después del path_helper de macOS para que ffmpeg-full vaya el primero.
asegurar_perfil() {
    local perfil linea='[ -f "$HOME/.local/share/drazo/entorno.sh" ] && . "$HOME/.local/share/drazo/entorno.sh"'
    for perfil in "$HOME/.zshenv" "$HOME/.zshrc" "$HOME/.bash_profile"; do
        if [ "$perfil" = "$HOME/.bash_profile" ] && [ ! -f "$perfil" ]; then continue; fi
        grep -qF '.local/share/drazo/entorno.sh' "$perfil" 2>/dev/null && continue
        printf '\n# Drazo Pro\n%s\n' "$linea" >> "$perfil"
    done
}

preparar_entorno() {
    mkdir -p "$DRAZO_DATOS"
    if [ ! -f "$DRAZO_ENTORNO" ]; then
        printf '# Entorno de Drazo Pro: lo escribe el instalador de Drazo.\n' > "$DRAZO_ENTORNO"
    fi
    chmod 600 "$DRAZO_ENTORNO"
    asegurar_perfil
}

# export NOMBRE='valor' en entorno.sh, sustituyendo el que hubiera.
entorno_poner() {
    preparar_entorno
    grep -v "^export $1=" "$DRAZO_ENTORNO" > "$DRAZO_ENTORNO.tmp"
    printf "export %s='%s'\n" "$1" "$2" >> "$DRAZO_ENTORNO.tmp"
    mv "$DRAZO_ENTORNO.tmp" "$DRAZO_ENTORNO"
    chmod 600 "$DRAZO_ENTORNO"
}

entorno_linea() {
    preparar_entorno
    grep -qxF -- "$1" "$DRAZO_ENTORNO" || printf '%s\n' "$1" >> "$DRAZO_ENTORNO"
}

instalar_brew() {
    local b
    if [ -z "$(ruta_brew)" ]; then
        echo "Instalando Homebrew con su instalador oficial (te pedirá la contraseña del Mac)..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    b="$(ruta_brew)"
    [ -n "$b" ] || return 1
    # Rutas fijas en lugar de «eval brew shellenv»: entorno.sh lo carga cada zsh y así no lanza procesos.
    entorno_linea "export PATH=\"$(dirname "$b"):$(dirname "$(dirname "$b")")/sbin:\$PATH\""
    cargar_brew
}

instalar_git() {
    if command -v brew >/dev/null 2>&1; then brew install git; return; fi
    xcode-select --install
    echo "Acepta la ventana de Apple y, cuando termine, vuelve a ejecutar el instalador de Drazo."
}

instalar_node() { requiere_brew && brew install node; }

instalar_claude() {
    echo "Instalando Claude Code con el instalador oficial de Anthropic..."
    curl -fsSL https://claude.ai/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
}

# El ffmpeg normal de Homebrew no trae zscale; ffmpeg-full sí, pero no se enlaza en el PATH.
instalar_ffmpeg() {
    requiere_brew || return 1
    brew install ffmpeg-full || return 1
    entorno_linea "export PATH=\"$(brew --prefix)/opt/ffmpeg-full/bin:\$PATH\""
    export PATH="$(brew --prefix)/opt/ffmpeg-full/bin:$PATH"
}

instalar_python() { requiere_brew && brew install python@3.12; }

instalar_venv() {
    buscar_python_base
    if [ -z "$PY_BASE_EXE" ]; then echo "${C_ROJO}No hay un Python 3.10 o superior para crear el entorno.${C_FIN}"; return 1; fi
    mkdir -p "$DRAZO_DATOS"
    if [ ! -x "$DRAZO_PYTHON" ] || ! "$DRAZO_PYTHON" -c 'import sys' >/dev/null 2>&1; then
        echo "Creando el entorno con Python $PY_BASE_VERSION..."
        "$PY_BASE_EXE" -m venv --clear "$DRAZO_VENV" || return 1
    fi
    echo "Instalando los paquetes de Python de Drazo (tarda unos minutos)..."
    "$DRAZO_PYTHON" -m pip install --disable-pip-version-check --upgrade pip
    "$DRAZO_PYTHON" -m pip install --disable-pip-version-check -r "$REQUISITOS_PYTHON"
}

instalar_playwright() {
    requiere_node || return 1
    mkdir -p "$DRAZO_NODE"
    npm install --prefix "$DRAZO_NODE" --no-audit --no-fund playwright-core
}

instalar_chrome() { requiere_brew && brew install --cask google-chrome; }

instalar_navegador() { requiere_node && HYPERFRAMES_NO_TELEMETRY=1 npx --yes hyperframes browser ensure; }

instalar_skills() { requiere_node && npx --yes skills add heygen-com/hyperframes -g -a claude-code --skill '*' -y; }

# Fuentes en ~/Library/Fonts (solo para tu usuario), con su huella SHA-256 comprobada.
instalar_fuentes() {
    local commit tmp faltan="|" fam familia ruta archivo nombre sha
    while IFS= read -r fam; do
        [ -n "$fam" ] && ! familia_instalada "$fam" && faltan="$faltan$fam|"
    done <<< "$(familias_fuentes)"
    commit="$(sed -n 's/^commit|//p' "$LISTA_FUENTES")"
    tmp="$(mktemp -d)"
    mkdir -p "$CARPETA_FUENTES"
    while IFS='|' read -r familia ruta archivo nombre sha; do
        case "$familia" in ""|\#*|commit) continue ;; esac
        case "$faltan" in *"|$familia|"*) ;; *) continue ;; esac
        if ! curl -fsSL "https://raw.githubusercontent.com/google/fonts/$commit/$ruta" -o "$tmp/$archivo"; then
            echo "  no pude descargar $archivo"; continue
        fi
        if [ "$(shasum -a 256 "$tmp/$archivo" | awk '{ print $1 }')" != "$sha" ]; then
            echo "  $archivo no coincide con su huella SHA-256: no se instala."; continue
        fi
        cp "$tmp/$archivo" "$CARPETA_FUENTES/$archivo" && echo "  instalada $archivo"
    done < "$LISTA_FUENTES"
    rm -rf "$tmp"
    echo "Las aplicaciones que ya estaban abiertas verán las fuentes al reiniciarse."
}

instalar_telemetria() {
    entorno_poner HYPERFRAMES_NO_TELEMETRY 1
    export HYPERFRAMES_NO_TELEMETRY=1
}

instalar_tesseract() {
    local arq sha zip tmp inst v
    echo "Tesseract es una herramienta de Mirage, no de Drazo, y es opcional."
    echo "Si lo instalas, aceptas sus condiciones (uso propio):"
    echo "  https://github.com/mirage-hq/Tesseract/blob/main/TERMS.md"
    echo "  https://mirage.app/legal/tesseract-terms"
    preguntar "¿Aceptas sus condiciones e instalo Tesseract?" n || return 0
    arq="$(uname -m)"
    [ "$(sysctl -in sysctl.proc_translated 2>/dev/null)" = "1" ] && arq="arm64"
    if [ "$arq" = "arm64" ]; then sha="$SHA256_TESSERACT_ARM64"; zip="tesseract-$VERSION_TESSERACT-darwin-arm64.zip"
    else sha="$SHA256_TESSERACT_X86_64"; zip="tesseract-$VERSION_TESSERACT-darwin-x86_64.zip"; fi
    tmp="$(mktemp -d)"
    echo "Descargando $zip (unos 90 MB)..."
    if ! curl -fL "https://github.com/mirage-hq/Tesseract/releases/download/v$VERSION_TESSERACT/$zip" -o "$tmp/$zip"; then
        echo "${C_ROJO}No se pudo descargar Tesseract.${C_FIN}"; rm -rf "$tmp"; return 1
    fi
    if [ "$(shasum -a 256 "$tmp/$zip" | awk '{ print $1 }')" != "$sha" ]; then
        echo "${C_ROJO}La huella SHA-256 del zip no coincide: no se instala.${C_FIN}"; rm -rf "$tmp"; return 1
    fi
    ditto -x -k "$tmp/$zip" "$tmp/extraido"
    inst="$(find "$tmp/extraido" -name install.sh -type f | head -n 1)"
    if [ -z "$inst" ]; then echo "${C_ROJO}El zip no trae install.sh.${C_FIN}"; rm -rf "$tmp"; return 1; fi
    bash "$inst"
    rm -rf "$tmp"
    v="$(leer_version "$("$TSRCT_RUTA" --version 2>/dev/null)")"
    if [ "$v" != "$VERSION_TESSERACT" ]; then echo "${C_ROJO}tsrct no responde con la versión $VERSION_TESSERACT (responde «$v»).${C_FIN}"; return 1; fi
    requiere_node || return 1
    npx --yes skills add "https://github.com/mirage-hq/Tesseract/tree/v$VERSION_TESSERACT/skills" -g -a claude-code \
        --skill tesseract-video --skill tesseract-motion -y
}

pedir_licencia() {
    local intento clave
    for intento in 1 2 3; do
        printf 'Pega tu clave de licencia de Drazo (empieza por drz_) y pulsa Intro: ' > /dev/tty
        IFS= read -r -s clave < /dev/tty || clave=""
        echo "" > /dev/tty
        clave="$(printf '%s' "$clave" | tr -d '[:space:]')"
        if [ -z "$clave" ]; then echo "No has pegado nada. Puedes ponerla más tarde volviendo a ejecutar el instalador."; return 0; fi
        case "$clave" in
            *\'*|*\"*|*\\*) ;;
            drz_????????*)
                entorno_poner DRAZO_LICENCIA "$clave"
                export DRAZO_LICENCIA="$clave"
                echo "${C_VERDE}Clave guardada (drz_…${clave: -4}).${C_FIN}"
                echo "Si tienes Claude Code abierto, ciérralo y vuelve a abrirlo desde una terminal nueva para que vea la clave."
                return 0 ;;
        esac
        echo "${C_AMARILLO}Eso no parece una clave de Drazo: empieza por drz_. Prueba otra vez.${C_FIN}"
    done
}

instalar_plugin() {
    local c; c="$(ruta_claude)"
    if [ -z "$c" ]; then echo "${C_ROJO}Falta Claude Code: no puedo instalar el plugin.${C_FIN}"; return 1; fi
    "$c" plugin marketplace add "${MARKETPLACE:-$REPO_DRAZO}" && "$c" plugin install "$ID_PLUGIN" --scope user
}

actualizar_plugin() {
    local c; c="$(ruta_claude)"
    "$c" plugin marketplace update drazo
    "$c" plugin update "$ID_PLUGIN"
}

# Pregunta de cada paso que se instala; vacío = no se instala desde aquí.
texto_accion() {
    case "$1" in
        brew) echo "Preparo Homebrew: lo instalo si falta y lo dejo cargado en la terminal (lo necesitan los demás pasos)" ;;
        git) echo "Instalo Git (Claude Code lo usa para traer el plugin de Drazo)" ;;
        node) echo "Instalo Node.js" ;;
        claude) echo "Instalo Claude Code con el instalador oficial" ;;
        ffmpeg) echo "Instalo ffmpeg-full (con libx264 y zscale)" ;;
        python) echo "Instalo Python 3.12" ;;
        venv) echo "Creo el entorno de Python de Drazo (unos 1-2 GB en $DRAZO_VENV)" ;;
        playwright) echo "Instalo playwright-core solo para Drazo (en $DRAZO_NODE)" ;;
        chrome) echo "Instalo Google Chrome" ;;
        navegador) echo "Descargo el navegador de HyperFrames" ;;
        skills) echo "Instalo las skills públicas de HyperFrames en Claude Code" ;;
        fuentes) echo "Instalo las fuentes Anton, Caveat, Poppins, Inter y JetBrains Mono para tu usuario" ;;
        telemetria) echo "Apago la telemetría de HyperFrames (HYPERFRAMES_NO_TELEMETRY=1)" ;;
    esac
}

estado_de() { local v="ESTADO_$1"; printf '%s' "${!v}"; }

CODIGO=1
principal() {
    local id texto plan="" linea
    echo ""
    echo "${C_CIAN}Drazo Pro · instalador para macOS${C_FIN}"
    echo "Para usar Drazo Pro necesitas Claude Code con una suscripción a Claude Max 5x o superior."
    [ "$SOLO_COMPROBAR" = "1" ] && echo "${C_AMARILLO}Modo solo comprobar: no se instala ni se cambia nada.${C_FIN}"
    echo ""
    cargar_brew
    for id in $COMPROBACIONES_DRAZO; do
        comprobar "$id"
        printf -v "ESTADO_$id" '%s' "$RES_ESTADO"
        printf -v "NOMBRE_$id" '%s' "$RES_NOMBRE"
    done

    if [ "$SOLO_COMPROBAR" = "1" ]; then
        for id in $COMPROBACIONES_DRAZO; do
            texto="$(texto_accion "$id")"
            [ "$(estado_de "$id")" = "falta" ] && [ -n "$texto" ] && plan="$plan$texto"$'\n'
        done
        [ "$(estado_de tesseract)" != "ok" ] && plan="${plan}Te ofrezco Tesseract $VERSION_TESSERACT (opcional, con las condiciones de Mirage)"$'\n'
        [ "$(estado_de licencia)" != "ok" ] && plan="${plan}Te pido la clave de licencia y la guardo en el entorno de Drazo (DRAZO_LICENCIA)"$'\n'
        if [ "$(estado_de plugin)" = "ok" ]; then plan="${plan}Te ofrezco actualizar el plugin de Drazo"$'\n'
        else plan="${plan}Añado el marketplace de Drazo (${MARKETPLACE:-$REPO_DRAZO}) e instalo el plugin $ID_PLUGIN"$'\n'; fi
        echo ""
        echo "${C_CIAN}Esto haría el instalador, pidiendo permiso en cada paso:${C_FIN}"
        printf '%s' "$plan" | while IFS= read -r linea; do [ -n "$linea" ] && echo "  - $linea"; done
        mostrar_arreglos
        if hay_faltas_obligatorias; then CODIGO=1; else CODIGO=0; fi
        return
    fi

    if [ "$(estado_de sistema)" = "falta" ]; then echo "${C_ROJO}Este equipo no cumple el mínimo para Drazo.${C_FIN}"; return; fi

    for id in $COMPROBACIONES_DRAZO; do
        texto="$(texto_accion "$id")"
        [ "$(estado_de "$id")" = "falta" ] && [ -n "$texto" ] || continue
        local v="NOMBRE_$id"
        paso "${!v}"
        if preguntar "¿$texto?"; then
            "instalar_$id"
            "comprobar_$id"
            mostrar_resultado
        fi
    done

    if [ "$(estado_de tesseract)" != "ok" ]; then paso "Tesseract $VERSION_TESSERACT (opcional)"; instalar_tesseract; fi

    paso "Clave de licencia de Drazo"
    comprobar_licencia
    if [ "$RES_ESTADO" = "ok" ]; then
        preguntar "Ya tienes una clave guardada ($RES_DETALLE). ¿Quieres cambiarla?" n && pedir_licencia
    else
        pedir_licencia
    fi

    paso "Plugin de Drazo para Claude Code"
    if [ "$(estado_de plugin)" = "ok" ]; then
        preguntar "¿Actualizo el plugin de Drazo a su última versión?" && actualizar_plugin
    else
        preguntar "¿Añado el marketplace de Drazo e instalo el plugin?" && instalar_plugin
    fi

    paso "Comprobación final"
    bash "$PLUGIN/scripts/drazo-doctor.sh"
    CODIGO=$?
    echo "${C_CIAN}Siguiente paso: cierra Claude Code si lo tienes abierto y abre una terminal nueva: así Claude Code y su terminal Bash ven la clave DRAZO_LICENCIA y las rutas nuevas.${C_FIN}"
    [ "$(estado_de cuenta)" = "ok" ] || echo "${C_CIAN}Después escribe claude y entra con tu cuenta de Claude Max (5x o superior).${C_FIN}"
    echo "${C_CIAN}Para tu primer vídeo: abre Claude Code en la carpeta del vídeo y dile «edítame el vídeo».${C_FIN}"
}

preparar_plugin || exit 1
. "$PLUGIN/scripts/drazo-comun.sh"
principal
exit "$CODIGO"
