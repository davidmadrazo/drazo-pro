#!/bin/bash
# Doctor de Drazo Pro para macOS: comprueba el equipo, la clave y el servidor,
# y termina con la lista de lo que falta y cómo arreglarlo. No cambia nada.
# Uso: bash drazo-doctor.sh

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/drazo-comun.sh"

comprobar_servidor() {
    local nombre="Servidor de Drazo (drazo_estado)" salida codigo resumen detalle
    if ! command -v node >/dev/null 2>&1; then resultado servidor "$nombre" falta "no se puede probar sin Node.js" "Instala Node.js y vuelve a pasar el doctor."; return; fi
    [ -n "$DRAZO_LICENCIA" ] || DRAZO_LICENCIA="$(valor_entorno DRAZO_LICENCIA)"
    salida="$(DRAZO_LICENCIA="$DRAZO_LICENCIA" node "$DRAZO_SCRIPTS/comprobar-servidor.mjs" 2>&1)"
    codigo=$?
    resumen="$(printf '%s\n' "$salida" | head -n 1)"
    detalle="$(printf '%s\n' "$salida" | tail -n +2 | tr '\n' ' ' | sed 's/ *$//')"
    case "$codigo" in
        0) resultado servidor "$nombre" ok "$resumen $detalle" ;;
        1) resultado servidor "$nombre" falta "$resumen" "El servidor dice: «$detalle». Si es la licencia, escribe al soporte de ProfimaxIA." ;;
        3) resultado servidor "$nombre" falta "sin clave, no se puede probar" "Pon tu clave con el instalador de Drazo." ;;
        *) resultado servidor "$nombre" falta "$resumen" "Comprueba tu conexión a internet y vuelve a probar en un rato. Detalle: $detalle" ;;
    esac
}

echo ""
echo "${C_CIAN}Drazo Pro · diagnóstico del equipo${C_FIN}"
echo "Carpeta de Drazo: $DRAZO_DATOS"
echo ""
for id in $COMPROBACIONES_DRAZO servidor; do
    comprobar "$id"
done
mostrar_arreglos
echo ""
if hay_faltas_obligatorias; then exit 1; fi
exit 0
