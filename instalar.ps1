# Instalador de Drazo Pro para Windows 10 y 11.
# Comprueba cada requisito y, si falta, lo instala pidiendo permiso en cada paso. Al final pasa el doctor.
# Uso:
#   powershell -NoProfile -ExecutionPolicy Bypass -File instalar.ps1                  instala lo que falte
#   powershell -NoProfile -ExecutionPolicy Bypass -File instalar.ps1 -SoloComprobar   solo mira, no cambia nada
#   ... -Marketplace <ruta o repo>   otra fuente para el marketplace (para pruebas)
# Este fichero va en UTF-8 con BOM: sin BOM, PowerShell 5.1 rompe las tildes.
param(
    [switch]$SoloComprobar,
    [string]$Marketplace
)

# Repo de GitHub con el marketplace y el plugin de Drazo (aún no publicado).
$RepoDrazo = 'davidmadrazo/drazo-pro'
$RamaDrazo = 'main'
$UrlBaseDrazo = "https://raw.githubusercontent.com/$RepoDrazo/$RamaDrazo"

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$FicherosPlugin = @(
    '.mcp.json', 'scripts/drazo-comun.ps1', 'scripts/drazo-doctor.ps1', 'scripts/comprobar-servidor.mjs',
    'scripts/comprobar-python.py', 'scripts/requisitos-python.txt', 'scripts/fuentes.txt'
)
$CarpetaTemporal = $null

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
    $sufijo = if ($PorDefectoNo) { '[s/N]' } else { '[S/n]' }
    while ($true) {
        $r = "$(Read-Host "$Texto $sufijo")".Trim().ToLower()
        if (-not $r) { return -not $PorDefectoNo }
        if ($r -in 's', 'si', 'sí', 'y', 'yes') { return $true }
        if ($r -in 'n', 'no') { return $false }
    }
}

function Paso([string]$Titulo) {
    Write-Host ''
    Write-Host "== $Titulo" -ForegroundColor Cyan
}

function Instalar-ConWinget([string]$Id, [string]$Nombre) {
    if (-not (Buscar-Comando 'winget')) {
        Write-Host "Sin winget no puedo instalar $Nombre. Instálalo a mano y vuelve a ejecutar el instalador." -ForegroundColor Red
        return
    }
    Write-Host "Instalando $Nombre con winget. Windows puede pedirte permiso de administrador."
    & winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) { Write-Host "winget terminó con el código $LASTEXITCODE." -ForegroundColor Yellow }
    Actualizar-Path
}

function Instalar-Claude {
    Write-Host 'Instalando Claude Code con el instalador oficial de Anthropic...'
    & powershell -NoProfile -ExecutionPolicy Bypass -Command 'irm https://claude.ai/install.ps1 | iex'
    Actualizar-Path
}

function Instalar-Entorno {
    $base = Buscar-PythonBase
    if (-not $base) { Write-Host 'No hay un Python 3.10 o superior para crear el entorno.' -ForegroundColor Red; return }
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

function Instalar-Playwright {
    if (-not (Buscar-Comando 'npm.cmd')) { Write-Host 'Falta Node.js: no puedo instalar playwright-core.' -ForegroundColor Red; return }
    New-Item -ItemType Directory -Force $DrazoNode | Out-Null
    & npm.cmd install --prefix $DrazoNode --no-audit --no-fund playwright-core
}

function Instalar-NavegadorHF {
    if (-not (Buscar-Comando 'npx.cmd')) { Write-Host 'Falta Node.js: no puedo preparar el navegador de HyperFrames.' -ForegroundColor Red; return }
    $env:HYPERFRAMES_NO_TELEMETRY = '1'
    & npx.cmd --yes hyperframes browser ensure
}

function Instalar-SkillsHF {
    if (-not (Buscar-Comando 'npx.cmd')) { Write-Host 'Falta Node.js: no puedo instalar las skills de HyperFrames.' -ForegroundColor Red; return }
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
                Write-Host "  $($f.Archivo) no coincide con su huella SHA-256: no se instala." -ForegroundColor Red
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
    Write-Host 'Las aplicaciones que ya estaban abiertas verán las fuentes al reiniciarse.'
}

function Poner-Telemetria {
    [Environment]::SetEnvironmentVariable('HYPERFRAMES_NO_TELEMETRY', '1', 'User')
    $env:HYPERFRAMES_NO_TELEMETRY = '1'
}

function Instalar-Tesseract {
    Write-Host 'Tesseract es una herramienta de Mirage, no de Drazo, y es opcional.'
    Write-Host 'Si lo instalas, aceptas sus condiciones (uso propio):'
    Write-Host '  https://github.com/mirage-hq/Tesseract/blob/main/TERMS.md'
    Write-Host '  https://mirage.app/legal/tesseract-terms'
    if (-not (Preguntar '¿Aceptas sus condiciones e instalo Tesseract?' -PorDefectoNo)) { return }
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
        $skills = "https://github.com/mirage-hq/Tesseract/tree/v$VersionTesseract/skills"
        $porSkill = foreach ($s in $SkillsTesseract) { '--skill'; $s }
        & npx.cmd --yes skills add $skills -g -a claude-code @porSkill -y --copy
    } catch {
        Write-Host "No se pudo instalar Tesseract: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Pedir-Licencia {
    for ($intento = 1; $intento -le 3; $intento++) {
        $segura = Read-Host 'Pega tu clave de licencia de Drazo (empieza por drz_) y pulsa Intro' -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura)
        try { $clave = "$([Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr))".Trim() } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        if (-not $clave) { Write-Host 'No has pegado nada. Puedes ponerla más tarde volviendo a ejecutar el instalador.' -ForegroundColor Yellow; return }
        if ($clave -match '^drz_\S{8,}$') {
            [Environment]::SetEnvironmentVariable('DRAZO_LICENCIA', $clave, 'User')
            $env:DRAZO_LICENCIA = $clave
            Write-Host ("Clave guardada (drz_…{0})." -f $clave.Substring($clave.Length - 4)) -ForegroundColor Green
            Write-Host 'Si tienes Claude Code abierto, ciérralo y vuelve a abrirlo: así la conexión con Drazo y su terminal Bash ven la clave.'
            return
        }
        Write-Host 'Eso no parece una clave de Drazo: empieza por drz_. Prueba otra vez.' -ForegroundColor Yellow
    }
}

function Instalar-Plugin {
    $claude = Ruta-Claude
    if (-not $claude) { Write-Host 'Falta Claude Code: no puedo instalar el plugin.' -ForegroundColor Red; return }
    $fuente = if ($Marketplace) { $Marketplace } else { $RepoDrazo }
    & $claude plugin marketplace add $fuente
    & $claude plugin install $IdPlugin --scope user
}

function Actualizar-Plugin {
    $claude = Ruta-Claude
    if (-not $claude) { Write-Host 'Falta Claude Code: no puedo actualizar el plugin.' -ForegroundColor Red; return }
    & $claude plugin marketplace update drazo
    & $claude plugin update $IdPlugin
}

function Principal {
    $acciones = [ordered]@{
        git        = @{ Texto = 'Instalo Git (Claude Code lo usa para traer el plugin de Drazo)'; Hacer = { Instalar-ConWinget 'Git.Git' 'Git' } }
        node       = @{ Texto = 'Instalo Node.js LTS'; Hacer = { Instalar-ConWinget 'OpenJS.NodeJS.LTS' 'Node.js LTS' } }
        claude     = @{ Texto = 'Instalo Claude Code con el instalador oficial'; Hacer = { Instalar-Claude } }
        ffmpeg     = @{ Texto = 'Instalo ffmpeg completo (con libx264 y zscale)'; Hacer = { Instalar-ConWinget 'Gyan.FFmpeg' 'ffmpeg' } }
        python     = @{ Texto = 'Instalo Python 3.12'; Hacer = { Instalar-ConWinget 'Python.Python.3.12' 'Python 3.12' } }
        venv       = @{ Texto = "Creo el entorno de Python de Drazo (unos 1-2 GB en $DrazoVenv)"; Hacer = { Instalar-Entorno } }
        playwright = @{ Texto = "Instalo playwright-core solo para Drazo (en $DrazoNode)"; Hacer = { Instalar-Playwright } }
        chrome     = @{ Texto = 'Instalo Google Chrome'; Hacer = { Instalar-ConWinget 'Google.Chrome' 'Google Chrome' } }
        navegador  = @{ Texto = 'Descargo el navegador de HyperFrames'; Hacer = { Instalar-NavegadorHF } }
        skills     = @{ Texto = 'Instalo las skills públicas de HyperFrames en Claude Code'; Hacer = { Instalar-SkillsHF } }
        fuentes    = @{ Texto = 'Instalo las fuentes Anton, Caveat, Poppins, Inter y JetBrains Mono para tu usuario'; Hacer = { Instalar-Fuentes } }
        telemetria = @{ Texto = 'Apago la telemetría de HyperFrames (HYPERFRAMES_NO_TELEMETRY=1)'; Hacer = { Poner-Telemetria } }
    }

    Write-Host ''
    Write-Host 'Drazo Pro · instalador para Windows' -ForegroundColor Cyan
    Write-Host 'Para usar Drazo Pro necesitas Claude Code con una suscripción a Claude Max 5x o superior.'
    if ($SoloComprobar) { Write-Host 'Modo solo comprobar: no se instala ni se cambia nada.' -ForegroundColor Yellow }
    Write-Host ''
    $resultados = @()
    $funcionDe = @{}
    foreach ($f in $ComprobacionesDrazo) {
        $r = Ejecutar-Comprobacion $f
        Mostrar-Resultado $r
        $resultados += $r
        $funcionDe[$r.Id] = $f
    }
    $estado = @{}
    foreach ($r in $resultados) { $estado[$r.Id] = $r.Estado }

    if ($SoloComprobar) {
        $plan = @($resultados | Where-Object { $_.Estado -eq 'falta' -and $acciones.Contains($_.Id) } | ForEach-Object { $acciones[$_.Id].Texto })
        if ($estado['tesseract'] -ne 'ok') { $plan += "Te ofrezco Tesseract $VersionTesseract (opcional, con las condiciones de Mirage)" }
        if ($estado['licencia'] -ne 'ok') { $plan += 'Te pido la clave de licencia y la guardo en la variable de usuario DRAZO_LICENCIA' }
        $fuente = if ($Marketplace) { $Marketplace } else { $RepoDrazo }
        if ($estado['plugin'] -eq 'ok') { $plan += 'Te ofrezco actualizar el plugin de Drazo' } else { $plan += "Añado el marketplace de Drazo ($fuente) e instalo el plugin $IdPlugin" }
        Write-Host ''
        Write-Host 'Esto haría el instalador, pidiendo permiso en cada paso:' -ForegroundColor Cyan
        foreach ($p in $plan) { Write-Host "  - $p" }
        Mostrar-Arreglos $resultados
        $script:CodigoSalida = [int](@($resultados | Where-Object { $_.Estado -eq 'falta' -and -not $_.Opcional }).Count -gt 0)
        return
    }

    if ($estado['sistema'] -eq 'falta') { Write-Host ($resultados | Where-Object Id -eq 'sistema').Arreglo -ForegroundColor Red; return }
    if ($estado['winget'] -eq 'falta') { Paso 'winget'; Write-Host ($resultados | Where-Object Id -eq 'winget').Arreglo -ForegroundColor Yellow }

    foreach ($r in $resultados) {
        if ($r.Estado -ne 'falta' -or -not $acciones.Contains($r.Id)) { continue }
        Paso $r.Nombre
        if (Preguntar "¿$($acciones[$r.Id].Texto)?") {
            try { & $acciones[$r.Id].Hacer } catch { Write-Host "Este paso ha fallado: $($_.Exception.Message)" -ForegroundColor Red }
            Mostrar-Resultado (Ejecutar-Comprobacion $funcionDe[$r.Id])
        }
    }

    if ($estado['tesseract'] -ne 'ok') {
        Paso "Tesseract $VersionTesseract (opcional)"
        Instalar-Tesseract
    }

    Paso 'Clave de licencia de Drazo'
    $licencia = $resultados | Where-Object Id -eq 'licencia'
    if ($licencia.Estado -eq 'ok') {
        if (Preguntar "Ya tienes una clave guardada ($($licencia.Detalle)). ¿Quieres cambiarla?" -PorDefectoNo) { Pedir-Licencia }
    } else { Pedir-Licencia }

    Paso 'Plugin de Drazo para Claude Code'
    if ($estado['plugin'] -eq 'ok') {
        if (Preguntar '¿Actualizo el plugin de Drazo a su última versión?') { Actualizar-Plugin }
    } elseif (Preguntar '¿Añado el marketplace de Drazo e instalo el plugin?') { Instalar-Plugin }

    Paso 'Comprobación final'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Plugin 'scripts\drazo-doctor.ps1')
    $script:CodigoSalida = $LASTEXITCODE
    Write-Host 'Siguiente paso: cierra esta ventana y Claude Code si lo tienes abierto, y abre una terminal nueva: así Claude Code y su terminal Bash ven la clave DRAZO_LICENCIA y las rutas nuevas.' -ForegroundColor Cyan
    if ($estado['cuenta'] -ne 'ok') { Write-Host 'Después escribe claude y entra con tu cuenta de Claude Max (5x o superior).' -ForegroundColor Cyan }
    Write-Host 'Para tu primer vídeo: abre Claude Code en la carpeta del vídeo y dile «edítame el vídeo».' -ForegroundColor Cyan
}

# Principal no devuelve nada a propósito: así la salida de winget, pip o npm se ve en pantalla.
$CodigoSalida = 1
$Plugin = Preparar-Plugin
try {
    . (Join-Path $Plugin 'scripts\drazo-comun.ps1')
    Principal
} finally {
    if ($CarpetaTemporal) { Remove-Item -LiteralPath $CarpetaTemporal -Recurse -Force -ErrorAction SilentlyContinue }
}
exit $CodigoSalida
