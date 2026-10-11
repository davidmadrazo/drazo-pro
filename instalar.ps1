# Instalador de Drazo Pro para Windows 10 y 11.
# Comprueba cada requisito e instala lo que falte. Normalmente lo ejecuta Claude siguiendo INSTALAR.md,
# después de pedir permiso en el chat; también sirve a mano desde PowerShell.
# Uso:
#   powershell -NoProfile -ExecutionPolicy Bypass -File instalar.ps1 -SoloComprobar     solo mira, no cambia nada
#   ... -Doctor                                         pasa el doctor completo (también prueba el servidor)
#   ... -Si [-Pasos git,node,...] [-Licencia drz_...] [-Carpeta <ruta>]   sin preguntas (pegar INSTALAR.md ya es su sí)
#       -Carpeta: crea ahí videos\ y el CLAUDE.md de Drazo
#   ... (sin opciones)                                  pregunta en la terminal antes de cada paso
#   ... -Marketplace <carpeta del repo>                 registra Drazo desde una carpeta local (pruebas)
# Pasos: git node claude ffmpeg python venv modelo playwright chrome navegador skills fuentes telemetria tesseract registrar
# Salida por paso: «== [paso] ...» al empezar y «-> [paso] ok|ya estaba|falta|error: ...» al acabar.
# Código de salida: 0 todo bien · 1 algún paso no quedó bien · 2 uso incorrecto · 3 equipo no compatible.
# Este fichero va en UTF-8 con BOM: sin BOM, PowerShell 5.1 rompe las tildes.
param(
    [switch]$SoloComprobar,
    [switch]$Doctor,
    [switch]$Si,
    [string]$Pasos,
    [string]$Licencia,
    [string]$Marketplace,
    [string]$Carpeta
)

# Repo de GitHub con el marketplace y el plugin de Drazo.
$RepoDrazo = 'davidmadrazo/drazo-pro'
$RamaDrazo = 'main'
$UrlBaseDrazo = "https://raw.githubusercontent.com/$RepoDrazo/$RamaDrazo"

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$FicherosPlugin = @(
    '.mcp.json', 'scripts/drazo-comun.ps1', 'scripts/drazo-doctor.ps1', 'scripts/comprobar-servidor.mjs',
    'scripts/ajustes-claude.mjs', 'scripts/comprobar-python.py', 'scripts/requisitos-python.txt', 'scripts/fuentes.txt'
)
$CarpetaTemporal = $null
$CodigoSalida = 1

# Desde una copia del repo usa sus ficheros; si el instalador llega suelto, baja los que necesita.
function Preparar-Plugin {
    if ($PSScriptRoot) {
        $local = Join-Path $PSScriptRoot 'plugins\drazo'
        if (Test-Path -LiteralPath (Join-Path $local 'scripts\drazo-comun.ps1')) { return $local }
    }
    $script:CarpetaTemporal = Join-Path $env:TEMP ('drazo-instalador-' + [guid]::NewGuid().ToString('N'))
    $destino = Join-Path $CarpetaTemporal 'plugin'
    foreach ($f in $FicherosPlugin) {
        $ruta = Join-Path $destino ($f -replace '/', '\')
        New-Item -ItemType Directory -Force (Split-Path $ruta) | Out-Null
        Invoke-WebRequest -UseBasicParsing -Uri "$UrlBaseDrazo/plugins/drazo/$f" -OutFile $ruta
    }
    $destino
}

function Preguntar([string]$Texto, [switch]$PorDefectoNo) {
    if ($Si) { return $true }
    $sufijo = if ($PorDefectoNo) { '[s/N]' } else { '[S/n]' }
    while ($true) {
        $r = "$(Read-Host "$Texto $sufijo")".Trim().ToLower()
        if (-not $r) { return -not $PorDefectoNo }
        if ($r -in 's', 'si', 'sí', 'y', 'yes') { return $true }
        if ($r -in 'n', 'no') { return $false }
    }
}

function Avisar([string]$Texto, [string]$Color = 'Yellow') { Write-Host $Texto -ForegroundColor $Color }

function Instalar-ConWinget([string]$Id, [string]$Nombre) {
    if (-not (Buscar-Comando 'winget')) { throw "sin winget no se puede instalar $Nombre; instala «Instalador de aplicación» desde Microsoft Store" }
    Write-Host "Instalando $Nombre con winget. Windows puede mostrar una ventana «¿Quieres permitir que esta aplicación haga cambios?»: hay que pulsar «Sí»."
    & winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity
    if ($LASTEXITCODE -ne 0) { Write-Host "winget terminó con el código $LASTEXITCODE." }
    Actualizar-Path
}

function Instalar-Claude {
    Write-Host 'Instalando Claude Code (la orden claude) con el instalador oficial de Anthropic...'
    & powershell -NoProfile -ExecutionPolicy Bypass -Command 'irm https://claude.ai/install.ps1 | iex'
    Actualizar-Path
}

function Instalar-Entorno {
    $base = Buscar-PythonBase
    if (-not $base) { throw 'no hay un Python 3.10 o superior para crear el entorno (paso python)' }
    New-Item -ItemType Directory -Force $DrazoDatos | Out-Null
    $roto = (Test-Path -LiteralPath $DrazoPython) -and ((Ejecutar $DrazoPython @('-c', 'import sys')).Codigo -ne 0)
    if (-not (Test-Path -LiteralPath $DrazoPython) -or $roto) {
        Write-Host "Creando el entorno con Python $($base.Version)..."
        & $base.Exe -m venv --clear $DrazoVenv
    }
    Write-Host 'Instalando los paquetes de Python de Drazo (tarda unos minutos)...'
    & $DrazoPython -m pip install --disable-pip-version-check --upgrade pip
    & $DrazoPython -m pip install --disable-pip-version-check -r $RequisitosPython
}

function Descargar-Modelo {
    if (-not (Test-Path -LiteralPath $DrazoPython)) { throw 'falta el entorno de Python de Drazo (paso venv)' }
    Write-Host 'Descargando el modelo de transcripción large-v3-turbo (unos 1,6 GB; tarda según la conexión)...'
    $env:HF_HUB_DISABLE_SYMLINKS_WARNING = '1'
    & $DrazoPython -c "from faster_whisper import download_model; download_model('large-v3-turbo')"
}

function Instalar-Playwright {
    if (-not (Buscar-Comando 'npm.cmd')) { throw 'falta Node.js (paso node)' }
    New-Item -ItemType Directory -Force $DrazoNode | Out-Null
    & npm.cmd install --prefix $DrazoNode --no-audit --no-fund playwright-core
}

function Instalar-NavegadorHF {
    if (-not (Buscar-Comando 'npx.cmd')) { throw 'falta Node.js (paso node)' }
    $env:HYPERFRAMES_NO_TELEMETRY = '1'
    & npx.cmd --yes hyperframes browser ensure
}

function Instalar-SkillsHF {
    if (-not (Buscar-Comando 'npx.cmd')) { throw 'falta Node.js (paso node)' }
    & npx.cmd --yes skills add heygen-com/hyperframes -g -a claude-code --skill '*' -y --copy
}

# Fuentes para tu usuario (sin permisos de administrador): fichero en la carpeta de fuentes
# del usuario y su entrada en el registro, que es lo que hace Windows al pulsar «Instalar».
function Instalar-Fuentes {
    $clave = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    if (-not (Test-Path -LiteralPath $clave)) { New-Item -Path $clave -Force | Out-Null }
    New-Item -ItemType Directory -Force $CarpetaFuentes | Out-Null
    $instaladas = Familias-Instaladas
    $tmp = Join-Path $env:TEMP ('drazo-fuentes-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $tmp | Out-Null
    try {
        foreach ($f in Leer-Fuentes) {
            $patron = '^' + [regex]::Escape($f.Familia) + '\b'
            if ($instaladas | Where-Object { $_ -match $patron }) { continue }
            $descarga = Join-Path $tmp $f.Archivo
            Invoke-WebRequest -UseBasicParsing -Uri $f.Url -OutFile $descarga
            if ((Get-FileHash -LiteralPath $descarga -Algorithm SHA256).Hash.ToLower() -ne $f.Sha256) {
                Write-Host "  $($f.Archivo) no coincide con su huella SHA-256: no se instala."
                continue
            }
            $destino = Join-Path $CarpetaFuentes $f.Archivo
            Copy-Item -LiteralPath $descarga -Destination $destino -Force
            New-ItemProperty -LiteralPath $clave -Name "$($f.Nombre) (TrueType)" -Value $destino -PropertyType String -Force | Out-Null
            Write-Host "  instalada $($f.Archivo)"
        }
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Ajustes-Claude([string[]]$Argumentos) {
    $node = Buscar-Comando 'node'
    if (-not $node) { throw 'falta Node.js (paso node)' }
    & $node $AjustesScript @Argumentos
    $codigo = $LASTEXITCODE
    Estado-Ajustes -Renovar | Out-Null
    if ($codigo -ne 0) { throw "no se pudieron guardar los ajustes de Claude (código $codigo)" }
}

function Poner-Telemetria { Ajustes-Claude @('telemetria') }

function Instalar-Tesseract {
    $zip = "tesseract-$VersionTesseract-windows-x86_64.zip"
    $tmp = Join-Path $env:TEMP ('drazo-tesseract-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $tmp | Out-Null
    try {
        $ruta = Join-Path $tmp $zip
        Write-Host "Descargando $zip (unos 115 MB)..."
        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/mirage-hq/Tesseract/releases/download/v$VersionTesseract/$zip" -OutFile $ruta
        $huella = (Get-FileHash -LiteralPath $ruta -Algorithm SHA256).Hash.ToLower()
        if ($huella -ne $Sha256Tesseract) { throw "la huella SHA-256 del zip no coincide ($huella)" }
        $extraido = Join-Path $tmp 'extraido'
        New-Item -ItemType Directory -Force $extraido | Out-Null
        if (Buscar-Comando 'tar.exe') { & tar.exe -xf $ruta -C $extraido } else { Expand-Archive -LiteralPath $ruta -DestinationPath $extraido -Force }
        $instalador = Get-ChildItem -LiteralPath $extraido -Recurse -Filter 'install.ps1' | Select-Object -First 1
        if (-not $instalador) { throw 'el zip no trae install.ps1' }
        & powershell -NoProfile -ExecutionPolicy Bypass -File $instalador.FullName
        $v = "" + (Leer-Version (Ejecutar $TsrctRuta @('--version')).Texto)
        if ($v -ne $VersionTesseract) { throw "tsrct no responde con la versión $VersionTesseract (responde «$v»)" }
        if (-not (Buscar-Comando 'npx.cmd')) { throw 'tsrct está instalado, pero falta Node.js para instalar sus skills' }
        $porSkill = foreach ($s in $SkillsTesseract) { '--skill'; $s }
        & npx.cmd --yes skills add "https://github.com/mirage-hq/Tesseract/tree/v$VersionTesseract/skills" -g -a claude-code @porSkill -y --copy
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Pedir-Licencia {
    for ($intento = 1; $intento -le 3; $intento++) {
        $segura = Read-Host 'Pega tu clave de licencia de Drazo (empieza por drz_) y pulsa Intro' -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura)
        try { $clave = "$([Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr))".Trim() } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        if (-not $clave) { return '' }
        if ($clave -match '^drz_\S{8,}$') { return $clave }
        Avisar 'Eso no parece una clave de Drazo: empieza por drz_. Prueba otra vez.'
    }
    ''
}

# Marketplace, plugin y licencia en los ajustes de Claude (settings.json, con copia de seguridad), el plugin
# descargado con la orden claude y, con -Carpeta, la carpeta de trabajo preparada.
function Registrar-Drazo {
    $clave = $Licencia
    if (-not $clave -and -not $Si) { $clave = Pedir-Licencia }
    $argumentos = @('registrar')
    if ($clave) { $argumentos += @('--licencia', $clave) }
    if ($Marketplace) { $argumentos += @('--fuente-local', $Marketplace) }
    Ajustes-Claude $argumentos
    # La app no siempre baja el plugin al reabrirse: se descarga e instala ya con la orden claude
    $c = Ruta-Claude
    if (-not $c) { Instalar-Claude; $c = Ruta-Claude }
    if (-not $c) { throw 'no encuentro la orden claude para descargar Drazo' }
    $plugin = @('instalar-plugin', '--claude', $c)
    if ($Marketplace) { $plugin += @('--fuente-local', $Marketplace) }
    Ajustes-Claude $plugin
    if ($Carpeta) { Ajustes-Claude @('carpeta', '--ruta', $Carpeta) }
}

function Comprobar-Registro {
    $p = Comprobar-Plugin
    $l = Comprobar-Licencia
    if ($p.Estado -eq 'falta') { return $p }
    if ($l.Estado -ne 'ok') { return $l }
    Nuevo-Resultado 'registrar' 'Drazo registrado con tu licencia' $p.Estado "$($p.Detalle); licencia $($l.Detalle)" $p.Arreglo
}

function Nuevo-Catalogo {
    [ordered]@{
        git        = @{ Comprobar = 'Comprobar-Git'; Hacer = { Instalar-ConWinget 'Git.Git' 'Git' }; Texto = 'Instalo Git (Claude lo usa para descargar Drazo y para su terminal Bash)' }
        node       = @{ Comprobar = 'Comprobar-Node'; Hacer = { Instalar-ConWinget 'OpenJS.NodeJS.LTS' 'Node.js LTS' }; Texto = 'Instalo Node.js' }
        claude     = @{ Comprobar = 'Comprobar-Claude'; Hacer = { Instalar-Claude }; Texto = 'Instalo Claude Code (la orden claude)' }
        ffmpeg     = @{ Comprobar = 'Comprobar-Ffmpeg'; Hacer = { Instalar-ConWinget 'Gyan.FFmpeg' 'ffmpeg' }; Texto = 'Instalo ffmpeg completo (con libx264 y zscale)' }
        python     = @{ Comprobar = 'Comprobar-Python'; Hacer = { Instalar-ConWinget 'Python.Python.3.12' 'Python 3.12' }; Texto = 'Instalo Python 3.12' }
        venv       = @{ Comprobar = 'Comprobar-Entorno'; Hacer = { Instalar-Entorno }; Texto = 'Creo el entorno de Python de Drazo (unos 1-2 GB; tarda varios minutos)' }
        modelo     = @{ Comprobar = 'Comprobar-Modelo'; Hacer = { Descargar-Modelo }; Texto = 'Descargo el modelo de transcripción large-v3-turbo (unos 1,6 GB)' }
        playwright = @{ Comprobar = 'Comprobar-Playwright'; Hacer = { Instalar-Playwright }; Texto = 'Instalo playwright-core solo para Drazo' }
        chrome     = @{ Comprobar = 'Comprobar-Chrome'; Hacer = { Instalar-ConWinget 'Google.Chrome' 'Google Chrome' }; Texto = 'Instalo Google Chrome' }
        navegador  = @{ Comprobar = 'Comprobar-NavegadorHF'; Hacer = { Instalar-NavegadorHF }; Texto = 'Descargo el navegador de HyperFrames' }
        skills     = @{ Comprobar = 'Comprobar-SkillsHF'; Hacer = { Instalar-SkillsHF }; Texto = 'Instalo las skills públicas de HyperFrames en Claude' }
        fuentes    = @{ Comprobar = 'Comprobar-Fuentes'; Hacer = { Instalar-Fuentes }; Texto = 'Instalo las fuentes Anton, Caveat, Poppins, Inter y JetBrains Mono para tu usuario' }
        telemetria = @{ Comprobar = 'Comprobar-Telemetria'; Hacer = { Poner-Telemetria }; Texto = 'Apago la telemetría de HyperFrames' }
        tesseract  = @{ Comprobar = 'Comprobar-Tesseract'; Hacer = { Instalar-Tesseract }; Texto = "Instalo Tesseract $VersionTesseract (opcional, de Mirage)" }
        registrar  = @{ Comprobar = 'Comprobar-Registro'; Hacer = { Registrar-Drazo }; Texto = 'Registro Drazo en Claude y guardo la clave de licencia' }
    }
}

# Un paso está hecho si no falta nada; Tesseract (opcional) solo si está del todo bien.
function Esta-Hecho($Id, $R) { if ($Id -eq 'tesseract') { $R.Estado -eq 'ok' } else { $R.Estado -ne 'falta' } }

function Principal {
    # Lo que instaló un paso anterior está en el registro, no en el PATH heredado de la app de Claude.
    Actualizar-Path
    if ($Doctor) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Plugin 'scripts\drazo-doctor.ps1')
        $script:CodigoSalida = $LASTEXITCODE
        return
    }
    $catalogo = Nuevo-Catalogo
    Write-Host ''
    Write-Host 'Drazo Pro · instalador para Windows' -ForegroundColor Cyan
    Write-Host 'Drazo Pro funciona con Claude (app de escritorio o Claude Code) y una suscripción de pago a Claude (recomendado Max 5x).'
    if ($SoloComprobar) { Write-Host 'Modo solo comprobar: no se instala ni se cambia nada.' -ForegroundColor Yellow }
    Write-Host ''
    $resultados = @(foreach ($f in $ComprobacionesDrazo) { $r = Ejecutar-Comprobacion $f; Mostrar-Resultado $r; $r })
    $sistema = $resultados | Where-Object Id -eq 'sistema'
    if ($sistema.Estado -eq 'falta') { Avisar $sistema.Arreglo 'Red'; $script:CodigoSalida = 3; return }
    $inicial = @{}
    foreach ($r in $resultados) { $inicial[$r.Id] = $r }
    $inicial['registrar'] = Ejecutar-Comprobacion 'Comprobar-Registro'

    if ($Pasos) {
        $lista = @($Pasos -split '[,\s]+' | Where-Object { $_ })
        $malos = @($lista | Where-Object { -not $catalogo.Contains($_) })
        if ($malos.Count) { Avisar "Pasos desconocidos: $($malos -join ', '). Válidos: $(@($catalogo.Keys) -join ' ')" 'Red'; $script:CodigoSalida = 2; return }
    } else {
        $lista = @($catalogo.Keys | Where-Object { $_ -notin 'tesseract', 'registrar' -and -not (Esta-Hecho $_ $inicial[$_]) })
        if (-not $Si -and -not (Esta-Hecho 'tesseract' $inicial['tesseract'])) { $lista += 'tesseract' }
        if ($Licencia -or -not (Esta-Hecho 'registrar' $inicial['registrar'])) { $lista += 'registrar' }
    }

    if ($SoloComprobar) {
        Write-Host ''
        if ($lista.Count) {
            Write-Host 'Esto haría el instalador, paso a paso:' -ForegroundColor Cyan
            foreach ($id in $lista) { Write-Host "  - [$id] $($catalogo[$id].Texto)" }
        }
        Mostrar-Arreglos $resultados
        $script:CodigoSalida = [int](@($resultados | Where-Object { $_.Estado -eq 'falta' -and -not $_.Opcional }).Count -gt 0)
        return
    }
    Ejecutar-Pasos $catalogo $lista
}

function Ejecutar-Pasos($Catalogo, $Lista) {
    $hechos = @(); $yaEstaban = @(); $fallan = @(); $omitidos = @(); $usoMalo = $false
    foreach ($id in $Lista) {
        $paso = $Catalogo[$id]
        Write-Host ''
        Write-Host "== [$id] $($paso.Texto)" -ForegroundColor Cyan
        $antes = Ejecutar-Comprobacion $paso.Comprobar
        $forzar = $id -eq 'registrar' -and $Licencia
        if ((Esta-Hecho $id $antes) -and -not $forzar) { Write-Host "-> [$id] ya estaba: $($antes.Detalle)"; $yaEstaban += $id; continue }
        if ($id -eq 'tesseract') {
            Write-Host 'Tesseract es de Mirage, no de Drazo. Al instalarlo se aceptan sus condiciones (uso propio):'
            Write-Host '  https://github.com/mirage-hq/Tesseract/blob/main/TERMS.md y https://mirage.app/legal/tesseract-terms'
            if (-not (Preguntar '¿Aceptas sus condiciones e instalo Tesseract?' -PorDefectoNo)) { Write-Host "-> [$id] omitido"; $omitidos += $id; continue }
        } elseif (-not (Preguntar "¿$($paso.Texto)?")) { Write-Host "-> [$id] omitido"; $omitidos += $id; continue }
        $ajustes = Estado-Ajustes
        if ($id -eq 'registrar' -and $Si -and -not $Licencia -and (-not $ajustes -or $ajustes['licencia'] -ne 'si')) {
            Write-Host "-> [$id] falta: no hay clave de licencia; pásala con -Licencia drz_..."
            $fallan += $id; $usoMalo = $true; continue
        }
        try {
            & $paso.Hacer
        } catch {
            Write-Host "-> [$id] error: $($_.Exception.Message)"
            $fallan += $id; continue
        }
        $despues = Ejecutar-Comprobacion $paso.Comprobar
        if (Esta-Hecho $id $despues) { Write-Host "-> [$id] ok: $($despues.Detalle)"; $hechos += $id }
        else { Write-Host "-> [$id] falta: $($despues.Detalle). $($despues.Arreglo)"; $fallan += $id }
    }
    Write-Host ''
    Write-Host ("RESUMEN: hechos={0}; ya estaban={1}; fallan={2}; omitidos={3}" -f ($hechos -join ','), ($yaEstaban -join ','), ($fallan -join ','), ($omitidos -join ','))
    if ($hechos | Where-Object { $_ -in 'git', 'node', 'ffmpeg', 'python', 'chrome', 'claude', 'registrar', 'telemetria' }) {
        Avisar 'Para que Claude vea lo instalado y a Drazo: cierra la app de Claude (o Claude Code) y vuelve a abrirla.' 'Cyan'
    }
    if (-not $Si) {
        Write-Host ''
        Write-Host '== Comprobación final' -ForegroundColor Cyan
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Plugin 'scripts\drazo-doctor.ps1')
        Avisar 'Después escribe «Hola Drazo» en Claude: te hará unas preguntas para conocer tu estilo. Si quieres probar ya, di «edítamelo viral».' 'Cyan'
    }
    $script:CodigoSalida = if ($usoMalo) { 2 } elseif ($fallan.Count) { 1 } else { 0 }
}

# Principal no devuelve nada a propósito: así la salida de winget, pip o npm se ve en pantalla.
$Plugin = Preparar-Plugin
try {
    . (Join-Path $Plugin 'scripts\drazo-comun.ps1')
    Principal
} finally {
    if ($CarpetaTemporal) { Remove-Item -LiteralPath $CarpetaTemporal -Recurse -Force -ErrorAction SilentlyContinue }
}
exit $CodigoSalida
