#!/bin/bash
# Instalador de Drazo Pro para macOS. Sin Homebrew ni sudo: todo va en la carpeta de Drazo
# (~/.local/share/drazo). Normalmente lo ejecuta Claude siguiendo INSTALAR.md, después de pedir
# permiso en el chat; también sirve a mano desde la Terminal.
# Uso:
#   bash instalar.sh --solo-comprobar                         solo mira, no cambia nada
#   bash instalar.sh --doctor                                 pasa el doctor completo (también prueba el servidor)
#   bash instalar.sh --si [--pasos git,node,...] [--licencia drz_...]   sin preguntas
#   bash instalar.sh                                          pregunta antes de cada paso
#   bash instalar.sh --marketplace <carpeta del repo>         registra Drazo desde una carpeta (pruebas)
# Pasos: git node claude ffmpeg python venv modelo playwright chrome navegador skills fuentes telemetria tesseract registrar
# Salida por paso: «== [paso] ...» al empezar y «-> [paso] ok|ya estaba|falta|error|pendiente: ...» al acabar.
# Código de salida: 0 todo bien · 1 algún paso no quedó bien · 2 uso incorrecto · 3 equipo no compatible
#                   · 4 esperando al usuario (ventana de Apple de las herramientas de desarrollo).

REPO_DRAZO="davidmadrazo/drazo-pro"
RAMA_DRAZO="main"
URL_BASE_DRAZO="https://raw.githubusercontent.com/$REPO_DRAZO/$RAMA_DRAZO"

SOLO_COMPROBAR=0; DOCTOR=0; SI=0; PASOS=""; LICENCIA=""; MARKETPLACE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --solo-comprobar) SOLO_COMPROBAR=1 ;;
        --doctor) DOCTOR=1 ;;
        --si) SI=1 ;;
        --pasos) PASOS="$2"; shift ;;
        --licencia) LICENCIA="$2"; shift ;;
        --marketplace) MARKETPLACE="$2"; shift ;;
        *) echo "Opción desconocida: $1 (usa --solo-comprobar, --si, --pasos, --licencia o --marketplace)"; exit 2 ;;
    esac
    shift
done

FICHEROS_PLUGIN=".mcp.json scripts/drazo-comun.sh scripts/drazo-doctor.sh scripts/comprobar-servidor.mjs scripts/ajustes-claude.mjs scripts/comprobar-python.py scripts/requisitos-python.txt scripts/fuentes.txt"
CARPETA_TEMPORAL=""
PLUGIN=""
CODIGO=1
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

# Con --si no pregunta (el permiso se pidió en el chat). Sin --si lee de la terminal aunque llegue por tubería.
preguntar() {
    local defecto="${2:-s}" sufijo="[S/n]" r
    [ "$SI" = "1" ] && return 0
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

# entorno.sh solo lleva rutas (node, ffmpeg y uv de Drazo). Lo carga ~/.zshenv, que lee todo zsh (también
# la terminal de Claude), y ~/.zshrc, que lo vuelve a cargar después del path_helper de macOS.
asegurar_entorno() {
    local perfil linea='[ -f "$HOME/.local/share/drazo/entorno.sh" ] && . "$HOME/.local/share/drazo/entorno.sh"'
    mkdir -p "$DRAZO_DATOS"
    {
        printf '# Entorno de Drazo Pro: lo escribe el instalador de Drazo.\n'
        printf 'for _d in "$HOME/.local/share/drazo/uv" "$HOME/.local/share/drazo/nodejs/bin" "$HOME/.local/share/drazo/ffmpeg"; do\n'
        printf '    case ":$PATH:" in *":$_d:"*) ;; *) [ -d "$_d" ] && PATH="$_d:$PATH" ;; esac\n'
        printf 'done\nunset _d\nexport PATH\n'
    } > "$DRAZO_ENTORNO"
    for perfil in "$HOME/.zshenv" "$HOME/.zshrc" "$HOME/.bash_profile"; do
        if [ "$perfil" = "$HOME/.bash_profile" ] && [ ! -f "$perfil" ]; then continue; fi
        grep -qF '.local/share/drazo/entorno.sh' "$perfil" 2>/dev/null && continue
        printf '\n# Drazo Pro\n%s\n' "$linea" >> "$perfil"
    done
    cargar_rutas_drazo
}

# Descarga a un fichero y comprueba su SHA-256; si no coincide, lo borra y falla.
descargar_verificado() {
    local url="$1" destino="$2" esperado="$3" real
    curl -fL --retry 2 -o "$destino" "$url" || return 1
    real="$(shasum -a 256 "$destino" | awk '{ print $1 }')"
    if [ "$real" != "$esperado" ]; then echo "La huella SHA-256 de $(basename "$destino") no coincide: no se instala."; rm -f "$destino"; return 1; fi
}

# git llega con las herramientas de desarrollo de Apple: macOS abre su ventana y la persona pulsa «Instalar».
# Se espera como mucho 9 minutos (las órdenes de Claude en primer plano se cortan a los 10).
instalar_git() {
    local espera=0
    tiene_clt && return 0
    xcode-select --install >/dev/null 2>&1
    echo "Se ha abierto una ventana de Apple para instalar las herramientas de desarrollo: hay que pulsar «Instalar»."
    while [ "$espera" -lt 540 ]; do
        sleep 15; espera=$((espera + 15))
        tiene_clt && return 0
    done
    echo "Aún se están instalando. Cuando termine la ventana de Apple, repite este paso."
    return 4
}

instalar_node() {
    local arq tar sha tmp
    arq="$(arquitectura)"
    if [ "$arq" = "arm64" ]; then tar="node-v$VERSION_NODE-darwin-arm64.tar.gz"; sha="$SHA256_NODE_ARM64"; else tar="node-v$VERSION_NODE-darwin-x64.tar.gz"; sha="$SHA256_NODE_X86_64"; fi
    tmp="$(mktemp -d)"
    echo "Descargando Node.js $VERSION_NODE (oficial de nodejs.org)..."
    descargar_verificado "https://nodejs.org/dist/v$VERSION_NODE/$tar" "$tmp/$tar" "$sha" || { rm -rf "$tmp"; return 1; }
    rm -rf "$DRAZO_NODEJS" && mkdir -p "$DRAZO_NODEJS"
    tar -xzf "$tmp/$tar" -C "$DRAZO_NODEJS" --strip-components 1
    rm -rf "$tmp"
    asegurar_entorno
}

# ffmpeg y ffprobe 9.0.2 estáticos (con libx264 y zscale) de ffmpeg.martin-riedl.de; descargados con curl,
# que no les pone la marca de cuarentena, así que macOS no los bloquea.
instalar_ffmpeg() {
    local arq url sha_ffmpeg sha_ffprobe tmp
    arq="$(arquitectura)"
    if [ "$arq" = "arm64" ]; then url="$URL_FFMPEG_ARM64"; sha_ffmpeg="$SHA256_FFMPEG_ARM64"; sha_ffprobe="$SHA256_FFPROBE_ARM64"
    else url="$URL_FFMPEG_X86_64"; sha_ffmpeg="$SHA256_FFMPEG_X86_64"; sha_ffprobe="$SHA256_FFPROBE_X86_64"; fi
    tmp="$(mktemp -d)"
    echo "Descargando ffmpeg 9.0.2 completo (unos 60 MB)..."
    descargar_verificado "$url/ffmpeg.zip" "$tmp/ffmpeg.zip" "$sha_ffmpeg" || { rm -rf "$tmp"; return 1; }
    descargar_verificado "$url/ffprobe.zip" "$tmp/ffprobe.zip" "$sha_ffprobe" || { rm -rf "$tmp"; return 1; }
    mkdir -p "$DRAZO_FFMPEG"
    ditto -x -k "$tmp/ffmpeg.zip" "$DRAZO_FFMPEG" && ditto -x -k "$tmp/ffprobe.zip" "$DRAZO_FFMPEG"
    chmod +x "$DRAZO_FFMPEG/ffmpeg" "$DRAZO_FFMPEG/ffprobe"
    rm -rf "$tmp"
    asegurar_entorno
}

# uv trae el Python 3.12 del entorno de Drazo, sin contraseña.
instalar_python() {
    local arq tar sha tmp
    arq="$(arquitectura)"
    if [ "$arq" = "arm64" ]; then tar="uv-aarch64-apple-darwin.tar.gz"; sha="$SHA256_UV_ARM64"; else tar="uv-x86_64-apple-darwin.tar.gz"; sha="$SHA256_UV_X86_64"; fi
    tmp="$(mktemp -d)"
    echo "Descargando uv $VERSION_UV..."
    descargar_verificado "https://github.com/astral-sh/uv/releases/download/$VERSION_UV/$tar" "$tmp/$tar" "$sha" || { rm -rf "$tmp"; return 1; }
    mkdir -p "$DRAZO_UV"
    tar -xzf "$tmp/$tar" -C "$DRAZO_UV" --strip-components 1
    rm -rf "$tmp"
    asegurar_entorno
}

instalar_venv() {
    local uv; uv="$(command -v uv 2>/dev/null)"
    mkdir -p "$DRAZO_DATOS"
    if [ -n "$uv" ]; then
        export UV_PYTHON_INSTALL_DIR="$DRAZO_DATOS/python" UV_CACHE_DIR="$DRAZO_DATOS/uv-cache"
        if [ ! -x "$DRAZO_PYTHON" ] || ! "$DRAZO_PYTHON" -c 'import sys' >/dev/null 2>&1; then
            echo "Creando el entorno con Python 3.12 (uv)..."
            "$uv" venv --clear --seed --python 3.12 "$DRAZO_VENV" || return 1
        fi
        echo "Instalando los paquetes de Python de Drazo (tarda unos minutos)..."
        "$uv" pip install --python "$DRAZO_PYTHON" -r "$REQUISITOS_PYTHON"
        return
    fi
    buscar_python_base
    if [ -z "$PY_BASE_EXE" ]; then echo "Falta uv (paso python)."; return 1; fi
    if [ ! -x "$DRAZO_PYTHON" ] || ! "$DRAZO_PYTHON" -c 'import sys' >/dev/null 2>&1; then "$PY_BASE_EXE" -m venv --clear "$DRAZO_VENV" || return 1; fi
    "$DRAZO_PYTHON" -m pip install --disable-pip-version-check --upgrade pip
    "$DRAZO_PYTHON" -m pip install --disable-pip-version-check -r "$REQUISITOS_PYTHON"
}

instalar_modelo() {
    if [ ! -x "$DRAZO_PYTHON" ]; then echo "Falta el entorno de Python de Drazo (paso venv)."; return 1; fi
    echo "Descargando el modelo de transcripción large-v3-turbo (unos 1,6 GB; tarda según la conexión)..."
    "$DRAZO_PYTHON" -c "from faster_whisper import download_model; download_model('large-v3-turbo')"
}

instalar_playwright() {
    command -v npm >/dev/null 2>&1 || { echo "Falta Node.js (paso node)."; return 1; }
    mkdir -p "$DRAZO_NODE"
    npm install --prefix "$DRAZO_NODE" --no-audit --no-fund playwright-core
}

# Chrome oficial de Google: a /Applications si se puede escribir ahí (cuentas de administrador), si no a ~/Applications.
instalar_chrome() {
    local tmp destino="/Applications"
    tmp="$(mktemp -d)"
    echo "Descargando Google Chrome (unos 250 MB)..."
    curl -fL --retry 2 -o "$tmp/chrome.dmg" "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg" || { rm -rf "$tmp"; return 1; }
    hdiutil attach -nobrowse -readonly -quiet -mountpoint "$tmp/volumen" "$tmp/chrome.dmg" || { rm -rf "$tmp"; return 1; }
    [ -w "$destino" ] || { destino="$HOME/Applications"; mkdir -p "$destino"; }
    ditto "$tmp/volumen/Google Chrome.app" "$destino/Google Chrome.app"
    hdiutil detach -quiet "$tmp/volumen"
    rm -rf "$tmp"
}

instalar_navegador() {
    command -v npx >/dev/null 2>&1 || { echo "Falta Node.js (paso node)."; return 1; }
    HYPERFRAMES_NO_TELEMETRY=1 npx --yes hyperframes browser ensure
}

instalar_skills() {
    command -v npx >/dev/null 2>&1 || { echo "Falta Node.js (paso node)."; return 1; }
    npx --yes skills add heygen-com/hyperframes -g -a claude-code --skill '*' -y
}

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
        descargar_verificado "https://raw.githubusercontent.com/google/fonts/$commit/$ruta" "$tmp/$archivo" "$sha" || continue
        cp "$tmp/$archivo" "$CARPETA_FUENTES/$archivo" && echo "  instalada $archivo"
    done < "$LISTA_FUENTES"
    rm -rf "$tmp"
}

ajustes_claude() {
    command -v node >/dev/null 2>&1 || { echo "Falta Node.js (paso node)."; return 1; }
    node "$AJUSTES_SCRIPT" "$@"
    local codigo=$?
    estado_ajustes --renovar
    return "$codigo"
}

instalar_telemetria() { ajustes_claude telemetria; }

instalar_tesseract() {
    local arq sha zip tmp inst v
    arq="$(arquitectura)"
    if [ "$arq" = "arm64" ]; then sha="$SHA256_TESSERACT_ARM64"; zip="tesseract-$VERSION_TESSERACT-darwin-arm64.zip"
    else sha="$SHA256_TESSERACT_X86_64"; zip="tesseract-$VERSION_TESSERACT-darwin-x86_64.zip"; fi
    tmp="$(mktemp -d)"
    echo "Descargando $zip (unos 90 MB)..."
    descargar_verificado "https://github.com/mirage-hq/Tesseract/releases/download/v$VERSION_TESSERACT/$zip" "$tmp/$zip" "$sha" || { rm -rf "$tmp"; return 1; }
    ditto -x -k "$tmp/$zip" "$tmp/extraido"
    inst="$(find "$tmp/extraido" -name install.sh -type f | head -n 1)"
    if [ -z "$inst" ]; then echo "El zip no trae install.sh."; rm -rf "$tmp"; return 1; fi
    bash "$inst"
    rm -rf "$tmp"
    v="$(leer_version "$("$TSRCT_RUTA" --version 2>/dev/null)")"
    if [ "$v" != "$VERSION_TESSERACT" ]; then echo "tsrct no responde con la versión $VERSION_TESSERACT (responde «$v»)."; return 1; fi
    command -v npx >/dev/null 2>&1 || { echo "tsrct está instalado, pero falta Node.js para sus skills."; return 1; }
    npx --yes skills add "https://github.com/mirage-hq/Tesseract/tree/v$VERSION_TESSERACT/skills" -g -a claude-code \
        --skill tesseract-video --skill tesseract-motion -y
}

instalar_claude() {
    echo "Instalando Claude Code (la orden claude) con el instalador oficial de Anthropic..."
    curl -fsSL https://claude.ai/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
}

pedir_licencia() {
    local intento clave
    for intento in 1 2 3; do
        printf 'Pega tu clave de licencia de Drazo (empieza por drz_) y pulsa Intro: ' > /dev/tty
        IFS= read -r -s clave < /dev/tty || clave=""
        echo "" > /dev/tty
        clave="$(printf '%s' "$clave" | tr -d '[:space:]')"
        [ -z "$clave" ] && return 0
        case "$clave" in drz_????????*) printf '%s' "$clave"; return 0 ;; esac
        echo "Eso no parece una clave de Drazo: empieza por drz_. Prueba otra vez." > /dev/tty
    done
}

# Marketplace, plugin y licencia en los ajustes de Claude (settings.json), con copia de seguridad.
instalar_registrar() {
    local clave="$LICENCIA"
    [ -z "$clave" ] && [ "$SI" != "1" ] && clave="$(pedir_licencia)"
    set -- registrar
    [ -n "$clave" ] && set -- "$@" --licencia "$clave"
    [ -n "$MARKETPLACE" ] && set -- "$@" --fuente-local "$MARKETPLACE"
    ajustes_claude "$@"
}

texto_paso() {
    case "$1" in
        git) echo "Instalo git (herramientas de desarrollo de Apple; Claude lo usa para descargar Drazo)" ;;
        node) echo "Instalo Node.js $VERSION_NODE en la carpeta de Drazo" ;;
        claude) echo "Instalo Claude Code (la orden claude)" ;;
        ffmpeg) echo "Instalo ffmpeg completo (con libx264 y zscale) en la carpeta de Drazo" ;;
        python) echo "Instalo uv, que trae el Python de Drazo" ;;
        venv) echo "Creo el entorno de Python de Drazo (unos 1-2 GB; tarda varios minutos)" ;;
        modelo) echo "Descargo el modelo de transcripción large-v3-turbo (unos 1,6 GB)" ;;
        playwright) echo "Instalo playwright-core solo para Drazo" ;;
        chrome) echo "Instalo Google Chrome" ;;
        navegador) echo "Descargo el navegador de HyperFrames" ;;
        skills) echo "Instalo las skills públicas de HyperFrames en Claude" ;;
        fuentes) echo "Instalo las fuentes Anton, Caveat, Poppins, Inter y JetBrains Mono para tu usuario" ;;
        telemetria) echo "Apago la telemetría de HyperFrames" ;;
        tesseract) echo "Instalo Tesseract $VERSION_TESSERACT (opcional, de Mirage)" ;;
        registrar) echo "Registro Drazo en Claude y guardo la clave de licencia" ;;
    esac
}

PASOS_VALIDOS="git node claude ffmpeg python venv modelo playwright chrome navegador skills fuentes telemetria tesseract registrar"

comprobar_paso() {
    case "$1" in
        venv) comprobar_venv ;;
        registrar) comprobar_registro ;;
        *) "comprobar_$1" ;;
    esac
}

# Un paso está hecho si no falta nada; Tesseract (opcional) solo si está del todo bien.
esta_hecho() {
    if [ "$1" = "tesseract" ]; then [ "$RES_ESTADO" = "ok" ]; else [ "$RES_ESTADO" != "falta" ]; fi
}

principal() {
    local id v lista="" codigo hechos="" ya="" fallan="" omitidos="" pendientes="" uso_malo=0
    echo ""
    echo "${C_CIAN}Drazo Pro · instalador para macOS${C_FIN}"
    echo "Drazo Pro funciona con Claude (app de escritorio o Claude Code) y una suscripción a Claude Max 5x o superior."
    [ "$SOLO_COMPROBAR" = "1" ] && echo "${C_AMARILLO}Modo solo comprobar: no se instala ni se cambia nada.${C_FIN}"
    echo ""
    cargar_rutas_drazo
    for id in $COMPROBACIONES_DRAZO; do
        comprobar "$id"
        printf -v "ESTADO_$id" '%s' "$RES_ESTADO"
    done
    if [ "$ESTADO_sistema" = "falta" ]; then echo "${C_ROJO}Este equipo no cumple el mínimo para Drazo.${C_FIN}"; CODIGO=3; return; fi
    comprobar_registro
    ESTADO_registrar="$RES_ESTADO"

    if [ -n "$PASOS" ]; then
        lista="$(printf '%s' "$PASOS" | tr ',' ' ')"
        for id in $lista; do
            case " $PASOS_VALIDOS " in *" $id "*) ;; *) echo "Pasos desconocidos: $id. Válidos: $PASOS_VALIDOS"; CODIGO=2; return ;; esac
        done
    else
        for id in $PASOS_VALIDOS; do
            case "$id" in tesseract|registrar) continue ;; esac
            v="ESTADO_$id"
            [ "${!v}" = "falta" ] && lista="$lista $id"
        done
        [ "$SI" != "1" ] && [ "$ESTADO_tesseract" != "ok" ] && lista="$lista tesseract"
        if [ -n "$LICENCIA" ] || [ "$ESTADO_registrar" = "falta" ]; then lista="$lista registrar"; fi
    fi

    if [ "$SOLO_COMPROBAR" = "1" ]; then
        if [ -n "$lista" ]; then
            echo ""
            echo "${C_CIAN}Esto haría el instalador, paso a paso:${C_FIN}"
            for id in $lista; do echo "  - [$id] $(texto_paso "$id")"; done
        fi
        mostrar_arreglos
        if hay_faltas_obligatorias; then CODIGO=1; else CODIGO=0; fi
        return
    fi

    for id in $lista; do
        echo ""
        echo "${C_CIAN}== [$id] $(texto_paso "$id")${C_FIN}"
        comprobar_paso "$id"
        if esta_hecho "$id" && ! { [ "$id" = "registrar" ] && [ -n "$LICENCIA" ]; }; then
            echo "-> [$id] ya estaba: $RES_DETALLE"; ya="$ya,$id"; continue
        fi
        if [ "$id" = "tesseract" ]; then
            echo "Tesseract es de Mirage, no de Drazo. Al instalarlo se aceptan sus condiciones (uso propio):"
            echo "  https://github.com/mirage-hq/Tesseract/blob/main/TERMS.md y https://mirage.app/legal/tesseract-terms"
            if ! preguntar "¿Aceptas sus condiciones e instalo Tesseract?" n; then echo "-> [$id] omitido"; omitidos="$omitidos,$id"; continue; fi
        elif ! preguntar "¿$(texto_paso "$id")?"; then
            echo "-> [$id] omitido"; omitidos="$omitidos,$id"; continue
        fi
        if [ "$id" = "registrar" ] && [ "$SI" = "1" ] && [ -z "$LICENCIA" ]; then
            estado_ajustes
            if [ "${AJ_licencia:-}" != "si" ]; then
                echo "-> [$id] falta: no hay clave de licencia; pásala con --licencia drz_..."; fallan="$fallan,$id"; uso_malo=1; continue
            fi
        fi
        "instalar_$id"; codigo=$?
        if [ "$codigo" = "4" ]; then echo "-> [$id] pendiente: esperando a la ventana de Apple; repite este paso cuando termine"; pendientes="$pendientes,$id"; continue; fi
        comprobar_paso "$id"
        if esta_hecho "$id"; then echo "-> [$id] ok: $RES_DETALLE"; hechos="$hechos,$id"
        elif [ "$codigo" != "0" ]; then echo "-> [$id] error: el paso terminó con el código $codigo. $RES_ARREGLO"; fallan="$fallan,$id"
        else echo "-> [$id] falta: $RES_DETALLE. $RES_ARREGLO"; fallan="$fallan,$id"; fi
    done
    echo ""
    echo "RESUMEN: hechos=${hechos#,}; ya estaban=${ya#,}; fallan=${fallan#,}; omitidos=${omitidos#,}; pendientes=${pendientes#,}"
    case ",$hechos," in
        *,git,*|*,node,*|*,ffmpeg,*|*,python,*|*,chrome,*|*,claude,*|*,registrar,*|*,telemetria,*)
            echo "${C_CIAN}Para que Claude vea lo instalado y a Drazo: cierra la app de Claude (o Claude Code) y vuelve a abrirla.${C_FIN}" ;;
    esac
    if [ "$SI" != "1" ]; then
        echo ""
        echo "${C_CIAN}== Comprobación final${C_FIN}"
        bash "$PLUGIN/scripts/drazo-doctor.sh"
        echo "${C_CIAN}Después escribe «Hola Drazo» en Claude: te hará unas preguntas para conocer tu estilo. Si quieres probar ya, di «edítamelo viral».${C_FIN}"
    fi
    if [ "$uso_malo" = "1" ]; then CODIGO=2
    elif [ -n "$fallan" ]; then CODIGO=1
    elif [ -n "$pendientes" ]; then CODIGO=4
    else CODIGO=0; fi
}

preparar_plugin || exit 1
. "$PLUGIN/scripts/drazo-comun.sh"
if [ "$DOCTOR" = "1" ]; then bash "$PLUGIN/scripts/drazo-doctor.sh"; exit $?; fi
principal
exit "$CODIGO"
