#!/bin/bash
# Hook SessionStart del plugin (hooks/hooks.json): avisa si el Node.js del equipo no tiene el último parche
# de seguridad de su rama. Lo decide node-parcheado.mjs; esto solo busca el node con el que ejecutarlo.
# Se lanza con bash en Mac y con el de Git Bash en Windows. Nunca falla: sin node, sin red o con cualquier
# error, no dice nada y sale con 0.
n="$(command -v node 2>/dev/null)"
# En Mac la app de Claude abierta desde el Finder puede no tener en el PATH el node de la carpeta de Drazo
# (lo pone ~/.zshenv, que sh no lee).
[ -z "$n" ] && [ -x "$HOME/.local/share/drazo/nodejs/bin/node" ] && n="$HOME/.local/share/drazo/nodejs/bin/node"
[ -n "$n" ] || exit 0
"$n" "$(dirname "${BASH_SOURCE[0]}")/node-parcheado.mjs" aviso 2>/dev/null
exit 0
