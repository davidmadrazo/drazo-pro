#!/bin/bash
# Pruebas del instalador de Mac para equipos con Intel: el ffmpeg de reserva (evermeet.cx) cuando no se llega a
# martin-riedl.de, y el entorno de Python solo con ruedas para no compilar llvmlite. Sin red y sin instalar nada:
# curl, ditto, uv, Python y la arquitectura van simulados.
# Uso: bash tests/instalador-mac-intel.test.sh
raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../plugins/drazo/scripts/drazo-comun.sh
. "$raiz/plugins/drazo/scripts/drazo-comun.sh"
# instalar.sh se ejecuta al cargarlo: se toman solo las funciones que se prueban.
eval "$(sed -n -e '/^descargar_verificado() {/,/^}/p' -e '/^bajar_ffmpeg_y_ffprobe() {/,/^}/p' \
    -e '/^instalar_ffmpeg() {/,/^}/p' "$raiz/instalar.sh")"

fallos=0
igual() {
    if [ "$2" = "$3" ]; then echo "ok    $1"; else echo "FALLA $1: esperaba «$3» y sale «$2»"; fallos=$((fallos + 1)); fi
}

# Las huellas de verdad están fijadas (64 caracteres hexadecimales), también las de la reserva.
for v in SHA256_FFMPEG_X86_64_RESERVA SHA256_FFPROBE_X86_64_RESERVA SHA256_FFMPEG_X86_64 SHA256_FFPROBE_X86_64; do
    igual "$v fijada" "$(printf '%s' "${!v}" | grep -cE '^[0-9a-f]{64}$')" "1"
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
REGISTRO="$tmp/curl.log"
ARQ=x86_64
CAIDO="martin-riedl.de"
arquitectura() { echo "$ARQ"; }
asegurar_entorno() { :; }
# curl simulado: anota la URL; las de $CAIDO fallan como un tiempo agotado (28) y las demás escriben «<fichero> de <host>».
curl() {
    local destino="" url=""
    while [ $# -gt 0 ]; do
        case "$1" in -o) destino="$2"; shift ;; http*) url="$1" ;; esac
        shift
    done
    echo "$url" >> "$REGISTRO"
    case "$url" in *"$CAIDO"*) return 28 ;; esac
    printf '%s de %s' "$(basename "$url")" "$(printf '%s' "$url" | awk -F/ '{ print $3 }')" > "$destino"
}
# ditto simulado: «descomprime» ffmpeg.zip o ffprobe.zip dejando el binario con lo que traía el zip.
ditto() { local zip="$3" carpeta="$4"; cp "$zip" "$carpeta/$(basename "$zip" .zip)"; }
huella() { printf '%s' "$1" | shasum -a 256 | awk '{ print $1 }'; }
preparar() {
    : > "$REGISTRO"
    DRAZO_FFMPEG="$tmp/ffmpeg-$1"
    URL_FFMPEG_X86_64="https://ffmpeg.martin-riedl.de/download/macos/amd64/1_9.0.2"
    URL_FFMPEG_ARM64="https://ffmpeg.martin-riedl.de/download/macos/arm64/1_9.0.2"
    SHA256_FFMPEG_X86_64="$(huella "ffmpeg.zip de ffmpeg.martin-riedl.de")"
    SHA256_FFPROBE_X86_64="$(huella "ffprobe.zip de ffmpeg.martin-riedl.de")"
    SHA256_FFMPEG_ARM64="$SHA256_FFMPEG_X86_64"; SHA256_FFPROBE_ARM64="$SHA256_FFPROBE_X86_64"
    URL_FFMPEG_X86_64_RESERVA="https://evermeet.cx/ffmpeg/ffmpeg-9.0.2.zip"
    URL_FFPROBE_X86_64_RESERVA="https://evermeet.cx/ffmpeg/ffprobe-9.0.2.zip"
    SHA256_FFMPEG_X86_64_RESERVA="$(huella "ffmpeg-9.0.2.zip de evermeet.cx")"
    SHA256_FFPROBE_X86_64_RESERVA="$(huella "ffprobe-9.0.2.zip de evermeet.cx")"
}
hosts() { awk -F/ '{ print $3 }' "$REGISTRO" | uniq | paste -sd, -; }

preparar intel-caido; ARQ=x86_64; CAIDO="martin-riedl.de"
instalar_ffmpeg > /dev/null; codigo=$?
igual "Intel sin martin-riedl.de: termina bien" "$codigo" "0"
igual "Intel sin martin-riedl.de: prueba martin-riedl.de y luego evermeet.cx" "$(hosts)" "ffmpeg.martin-riedl.de,evermeet.cx"
igual "Intel sin martin-riedl.de: ffmpeg de evermeet.cx" "$(cat "$DRAZO_FFMPEG/ffmpeg" 2>/dev/null)" "ffmpeg-9.0.2.zip de evermeet.cx"
igual "Intel sin martin-riedl.de: ffprobe de evermeet.cx" "$(cat "$DRAZO_FFMPEG/ffprobe" 2>/dev/null)" "ffprobe-9.0.2.zip de evermeet.cx"

preparar intel-bien; ARQ=x86_64; CAIDO="nada"
instalar_ffmpeg > /dev/null; codigo=$?
igual "Intel con martin-riedl.de: termina bien" "$codigo" "0"
igual "Intel con martin-riedl.de: no toca la reserva" "$(hosts)" "ffmpeg.martin-riedl.de"
igual "Intel con martin-riedl.de: ffprobe de martin-riedl.de" "$(cat "$DRAZO_FFMPEG/ffprobe" 2>/dev/null)" "ffprobe.zip de ffmpeg.martin-riedl.de"

preparar intel-huella-mala; ARQ=x86_64; CAIDO="martin-riedl.de"
SHA256_FFPROBE_X86_64_RESERVA="$(huella "otra cosa")"
instalar_ffmpeg > /dev/null; codigo=$?
igual "reserva con huella que no cuadra: falla" "$codigo" "1"
igual "reserva con huella que no cuadra: no instala nada" "$(ls "$DRAZO_FFMPEG" 2>/dev/null)" ""

preparar arm-caido; ARQ=arm64; CAIDO="martin-riedl.de"
instalar_ffmpeg > /dev/null; codigo=$?
igual "Apple Silicon sin martin-riedl.de: falla (evermeet.cx es solo Intel)" "$codigo" "1"
igual "Apple Silicon sin martin-riedl.de: no baja la reserva de Intel" "$(hosts)" "ffmpeg.martin-riedl.de"

# Entorno de Python: en Intel uv y pip solo instalan ruedas (si no, compilan llvmlite y piden CMake); en Apple
# Silicon, como siempre. uv y el Python del entorno van simulados: anotan con qué se les llama.
bin="$tmp/bin"; mkdir -p "$bin"
printf '#!/bin/sh\necho "uv $*" >> "%s"\n' "$REGISTRO" > "$bin/uv"
printf '#!/bin/sh\necho "python $*" >> "%s"\n' "$REGISTRO" > "$tmp/python"
chmod +x "$bin/uv" "$tmp/python"
eval "$(sed -n '/^instalar_venv() {/,/^}/p' "$raiz/instalar.sh")"
buscar_python_base() { PY_BASE_EXE="$tmp/python"; }
DRAZO_DATOS="$tmp/datos"; DRAZO_PYTHON="$tmp/python"; REQUISITOS_PYTHON="$tmp/requisitos-python.txt"
instalacion() { grep -E "^(uv|python) .*install" "$REGISTRO" | grep -v -- "--upgrade pip" | sed "s|$tmp|T|g"; }

: > "$REGISTRO"; ARQ=x86_64
PATH="$bin:$PATH" instalar_venv > /dev/null
igual "Intel con uv: solo ruedas" "$(instalacion)" "uv pip install --python T/python --no-build -r T/requisitos-python.txt"
: > "$REGISTRO"; ARQ=arm64
PATH="$bin:$PATH" instalar_venv > /dev/null
igual "Apple Silicon con uv: como siempre" "$(instalacion)" "uv pip install --python T/python -r T/requisitos-python.txt"
sin_uv="$(printf '%s' "$PATH" | tr ':' '\n' | while IFS= read -r d; do [ -x "$d/uv" ] || printf '%s:' "$d"; done)"
: > "$REGISTRO"; ARQ=x86_64
PATH="$sin_uv" instalar_venv > /dev/null
igual "Intel sin uv (pip): solo ruedas" "$(instalacion)" \
    "python -m pip install --disable-pip-version-check --only-binary=:all: -r T/requisitos-python.txt"
: > "$REGISTRO"; ARQ=arm64
PATH="$sin_uv" instalar_venv > /dev/null
igual "Apple Silicon sin uv (pip): como siempre" "$(instalacion)" "python -m pip install --disable-pip-version-check -r T/requisitos-python.txt"

echo ""
if [ "$fallos" -eq 0 ]; then echo "Todas las pruebas pasan."; else echo "$fallos pruebas fallan."; exit 1; fi
