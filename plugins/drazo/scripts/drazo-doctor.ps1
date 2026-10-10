# Doctor de Drazo Pro para Windows: comprueba el equipo, la clave y el servidor,
# y termina con la lista de lo que falta y cómo arreglarlo. No cambia nada.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File drazo-doctor.ps1
# Este fichero va en UTF-8 con BOM: sin BOM, PowerShell 5.1 rompe las tildes.

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'drazo-comun.ps1')

function Comprobar-Servidor {
    $nombre = 'Servidor de Drazo (drazo_estado)'
    $node = Buscar-Comando 'node'
    if (-not $node) { return Nuevo-Resultado 'servidor' $nombre 'falta' 'no se puede probar sin Node.js' 'Instala Node.js y vuelve a pasar el doctor.' }
    # La clave guardada se pasa solo a esta prueba, sin dejarla en el entorno del doctor.
    $previa = $env:DRAZO_LICENCIA
    if (-not $env:DRAZO_LICENCIA) { $env:DRAZO_LICENCIA = [Environment]::GetEnvironmentVariable('DRAZO_LICENCIA', 'User') }
    try { $r = Ejecutar $node @((Join-Path $DrazoScripts 'comprobar-servidor.mjs')) } finally { $env:DRAZO_LICENCIA = $previa }
    $resumen = $r.Lineas | Select-Object -First 1
    $detalle = (($r.Lineas | Select-Object -Skip 1) -join ' ').Trim()
    switch ($r.Codigo) {
        0 { return Nuevo-Resultado 'servidor' $nombre 'ok' ("$resumen $detalle").Trim() }
        1 { return Nuevo-Resultado 'servidor' $nombre 'falta' $resumen "El servidor dice: «$detalle». Si es la licencia, escribe al soporte de ProfimaxIA." }
        3 { return Nuevo-Resultado 'servidor' $nombre 'falta' 'sin clave, no se puede probar' 'Pon tu clave con el instalador de Drazo.' }
        default { return Nuevo-Resultado 'servidor' $nombre 'falta' $resumen "Comprueba tu conexión a internet y vuelve a probar en un rato. Detalle: $detalle" }
    }
}

Write-Host ''
Write-Host 'Drazo Pro · diagnóstico del equipo' -ForegroundColor Cyan
Write-Host "Carpeta de Drazo: $DrazoDatos"
Write-Host ''

$resultados = @()
foreach ($funcion in $ComprobacionesDrazo + 'Comprobar-Servidor') {
    $r = Ejecutar-Comprobacion $funcion
    Mostrar-Resultado $r
    $resultados += $r
}
Mostrar-Arreglos $resultados
Write-Host ''

$faltan = @($resultados | Where-Object { $_.Estado -eq 'falta' -and -not $_.Opcional })
if ($faltan.Count) { exit 1 }
exit 0
