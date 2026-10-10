# Comprobaciones de Drazo Pro en Windows, compartidas por el instalador y el doctor.
# Se carga con: . "<carpeta>\drazo-comun.ps1"   (Windows PowerShell 5.1 o superior)
# Este fichero va en UTF-8 con BOM: sin BOM, PowerShell 5.1 rompe las tildes.

$DrazoScripts     = $PSScriptRoot
$DrazoDatos       = Join-Path $env:LOCALAPPDATA 'Drazo'
$DrazoVenv        = Join-Path $DrazoDatos 'venv'
$DrazoPython      = Join-Path $DrazoVenv 'Scripts\python.exe'
$DrazoNode        = Join-Path $DrazoDatos 'node'
$RequisitosPython = Join-Path $DrazoScripts 'requisitos-python.txt'
$ListaFuentes     = Join-Path $DrazoScripts 'fuentes.txt'
$CarpetaFuentes   = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$VersionTesseract = '0.2.0'
$Sha256Tesseract  = '35822d306209476d5c80ac3fafed6be6110afd70840f6c7179e5a35caf57b988'
$TsrctRuta        = Join-Path $env:LOCALAPPDATA 'Tesseract\bin\tsrct.cmd'
$SkillsTesseract  = @('tesseract-video', 'tesseract-motion')
$IdPlugin         = 'drazo@drazo'
$NodeMinimo       = [version]'22.0.0'
$PythonMinimo     = [version]'3.10.0'
$DiscoMinimoGB    = 10

function Nuevo-Resultado {
    param(
        [string]$Id, [string]$Nombre,
        [ValidateSet('ok', 'falta', 'aviso')][string]$Estado,
        [string]$Detalle = '', [string]$Arreglo = '', [switch]$Opcional
    )
    [pscustomobject]@{
        Id = $Id; Nombre = $Nombre; Estado = $Estado
        Detalle = $Detalle; Arreglo = $Arreglo; Opcional = [bool]$Opcional
    }
}

# Ejecuta un programa sin que un error suyo pare el script. Devuelve código y líneas de salida.
function Ejecutar {
    param([string]$Programa, [string[]]$Argumentos = @())
    $previo = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lineas = @(& $Programa @Argumentos 2>&1 | ForEach-Object { $_.ToString() })
        [pscustomobject]@{ Codigo = $LASTEXITCODE; Lineas = $lineas; Texto = ($lineas -join "`n") }
    } catch {
        [pscustomobject]@{ Codigo = -1; Lineas = @($_.Exception.Message); Texto = $_.Exception.Message }
    } finally {
        $ErrorActionPreference = $previo
    }
}

function Leer-Version([string]$Texto) {
    if ($Texto -match '(\d+)\.(\d+)(?:\.(\d+))?') {
        $parche = if ($Matches[3]) { $Matches[3] } else { '0' }
        return [version]("{0}.{1}.{2}" -f $Matches[1], $Matches[2], $parche)
    }
    $null
}

function Buscar-Comando([string]$Nombre) {
    $c = Get-Command $Nombre -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { $c.Source } else { $null }
}

# Tras instalar algo, el PATH de esta ventana no se entera solo: se recarga del registro.
function Actualizar-Path {
    $partes = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
        [Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
        (Join-Path $env:USERPROFILE '.local\bin')
        $env:Path -split ';'
    )
    $env:Path = (($partes | Where-Object { $_ } | Select-Object -Unique) -join ';')
}

# Claude Code recién instalado puede no estar aún en el PATH de esta ventana.
function Ruta-Claude {
    $c = Buscar-Comando 'claude'
    if ($c) { return $c }
    $nativo = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path -LiteralPath $nativo) { return $nativo }
    $null
}

# La terminal Bash de Claude Code en Windows es Git Bash (no el bash.exe de WSL de System32).
function Ruta-GitBash {
    if ($env:CLAUDE_CODE_GIT_BASH_PATH -and (Test-Path -LiteralPath $env:CLAUDE_CODE_GIT_BASH_PATH)) { return $env:CLAUDE_CODE_GIT_BASH_PATH }
    $rutas = @()
    $git = Buscar-Comando 'git'
    if ($git) { $rutas += Join-Path (Split-Path (Split-Path $git -Parent) -Parent) 'bin\bash.exe' }
    foreach ($base in $env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs')) {
        if ($base) { $rutas += Join-Path $base 'Git\bin\bash.exe' }
    }
    $rutas | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

function Carpeta-ConfigClaude {
    if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
}

function Leer-Fuentes {
    $commit = $null
    $lista = foreach ($linea in Get-Content -LiteralPath $ListaFuentes -Encoding UTF8) {
        if (-not $linea.Trim() -or $linea.StartsWith('#')) { continue }
        $c = $linea.Split('|')
        if ($c[0] -eq 'commit') { $commit = $c[1]; continue }
        [pscustomobject]@{ Familia = $c[0]; Ruta = $c[1]; Archivo = $c[2]; Nombre = $c[3]; Sha256 = $c[4] }
    }
    $lista | ForEach-Object { $_ | Add-Member -NotePropertyName Url -NotePropertyValue "https://raw.githubusercontent.com/google/fonts/$commit/$($_.Ruta)" -PassThru }
}

function Familias-Instaladas {
    $nombres = foreach ($clave in 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts', 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') {
        $p = Get-Item -LiteralPath $clave -ErrorAction SilentlyContinue
        if ($p) { $p.GetValueNames() }
    }
    @($nombres)
}

# Python de base para crear el entorno de Drazo. Se buscan las instalaciones registradas
# (PEP 514) y las del PATH; se descartan las de conda (sus entornos pierden SSL en Windows).
function Buscar-PythonBase {
    $candidatos = New-Object System.Collections.Generic.List[string]
    foreach ($raiz in 'HKCU:\SOFTWARE\Python\PythonCore', 'HKLM:\SOFTWARE\Python\PythonCore', 'HKLM:\SOFTWARE\WOW6432Node\Python\PythonCore') {
        foreach ($v in (Get-ChildItem -LiteralPath $raiz -ErrorAction SilentlyContinue)) {
            $ip = Get-ItemProperty -LiteralPath (Join-Path $v.PSPath 'InstallPath') -ErrorAction SilentlyContinue
            if (-not $ip) { continue }
            $exe = $ip.ExecutablePath
            if (-not $exe -and $ip.'(default)') { $exe = Join-Path $ip.'(default)' 'python.exe' }
            if ($exe -and (Test-Path -LiteralPath $exe)) { $candidatos.Add($exe) }
        }
    }
    foreach ($c in @(Get-Command python, python3 -All -ErrorAction SilentlyContinue)) { $candidatos.Add($c.Source) }
    $preferencia = @{ '3.12' = 0; '3.13' = 1; '3.11' = 2; '3.14' = 3; '3.10' = 4 }
    $mejor = $null
    foreach ($exe in ($candidatos | Select-Object -Unique)) {
        $r = Ejecutar $exe @('-c', "import os,sys; print('%d.%d.%d' % sys.version_info[:3]); print(sys.executable); print(os.path.isdir(os.path.join(sys.prefix,'conda-meta')))")
        if ($r.Codigo -ne 0 -or $r.Lineas.Count -lt 3) { continue }
        $version = Leer-Version $r.Lineas[0]
        if (-not $version -or $version -lt $PythonMinimo -or $r.Lineas[2] -eq 'True') { continue }
        $corta = '{0}.{1}' -f $version.Major, $version.Minor
        $orden = if ($preferencia.ContainsKey($corta)) { $preferencia[$corta] } else { 5 }
        if (-not $mejor -or $orden -lt $mejor.Orden) {
            $mejor = [pscustomobject]@{ Exe = $r.Lineas[1].Trim(); Version = $version; Orden = $orden }
        }
    }
    $mejor
}

# Saca el JSON de una salida que puede traer avisos antes o después.
function Json-DeTexto([string]$Texto) {
    if (-not $Texto) { return $null }
    $inicio = $Texto.IndexOfAny([char[]]'[{')
    $fin = $Texto.LastIndexOfAny([char[]]']}')
    if ($inicio -lt 0 -or $fin -le $inicio) { return $null }
    try { $Texto.Substring($inicio, $fin - $inicio + 1) | ConvertFrom-Json } catch { $null }
}

function Ruta-Chrome {
    $rutas = @()
    foreach ($base in $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA) {
        if ($base) { $rutas += Join-Path $base 'Google\Chrome\Application\chrome.exe' }
    }
    foreach ($clave in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe') {
        $p = Get-ItemProperty -LiteralPath $clave -ErrorAction SilentlyContinue
        if ($p -and $p.'(default)') { $rutas += $p.'(default)'.Trim('"') }
    }
    $rutas | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

# El navegador que usa HyperFrames para renderizar (chrome-headless-shell en su caché).
function Ruta-NavegadorHyperFrames {
    if ($env:HYPERFRAMES_BROWSER_PATH -and (Test-Path -LiteralPath $env:HYPERFRAMES_BROWSER_PATH)) { return $env:HYPERFRAMES_BROWSER_PATH }
    $raices = (Join-Path $env:USERPROFILE '.cache\hyperframes\chrome\chrome-headless-shell'), (Join-Path $env:USERPROFILE '.cache\puppeteer\chrome-headless-shell')
    foreach ($raiz in $raices) {
        $exe = Get-ChildItem -LiteralPath $raiz -Directory -ErrorAction SilentlyContinue |
            Sort-Object { Leer-Version $_.Name } -Descending |
            ForEach-Object { Join-Path $_.FullName 'chrome-headless-shell-win64\chrome-headless-shell.exe' } |
            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($exe) { return $exe }
    }
    $null
}

function Comprobar-Sistema {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $arq = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $build = if ($os) { [int]$os.BuildNumber } else { [Environment]::OSVersion.Version.Build }
    $nombre = if ($os) { $os.Caption } else { 'Windows' }
    $det = "$nombre (compilación $build, $arq)"
    if ($build -lt 17763) { return Nuevo-Resultado 'sistema' 'Windows 10 (1809) o 11' 'falta' $det 'Drazo necesita Windows 10 (versión 1809 o posterior) o Windows 11.' }
    if ($arq -ne 'AMD64') { return Nuevo-Resultado 'sistema' 'Windows 10 (1809) o 11' 'aviso' $det 'Drazo está probado en equipos x64; en ARM puede fallar algo (Tesseract no tiene versión ARM).' }
    Nuevo-Resultado 'sistema' 'Windows 10 (1809) o 11' 'ok' $det
}

function Comprobar-Winget {
    $exe = Buscar-Comando 'winget'
    if (-not $exe) { return Nuevo-Resultado 'winget' 'winget (instalador de Windows)' 'falta' 'no está' 'Instala «Instalador de aplicación» desde Microsoft Store: https://apps.microsoft.com/detail/9NBLGGH4NNS1' }
    Nuevo-Resultado 'winget' 'winget (instalador de Windows)' 'ok' ((Ejecutar $exe @('--version')).Lineas | Select-Object -First 1)
}

function Comprobar-Git {
    $exe = Buscar-Comando 'git'
    if (-not $exe) { return Nuevo-Resultado 'git' 'Git' 'falta' 'no está' 'winget install --id Git.Git -e' }
    Nuevo-Resultado 'git' 'Git' 'ok' ("" + (Leer-Version (Ejecutar $exe @('--version')).Texto))
}

function Comprobar-Node {
    $nombre = 'Node.js 22 o superior'
    $exe = Buscar-Comando 'node'
    if (-not $exe) { return Nuevo-Resultado 'node' $nombre 'falta' 'no está' 'winget install --id OpenJS.NodeJS.LTS -e' }
    $v = Leer-Version (Ejecutar $exe @('--version')).Texto
    if (-not $v -or $v -lt $NodeMinimo) { return Nuevo-Resultado 'node' $nombre 'falta' "versión $v" 'Actualiza Node.js: winget install --id OpenJS.NodeJS.LTS -e' }
    if (-not (Buscar-Comando 'npm.cmd')) { return Nuevo-Resultado 'node' $nombre 'falta' "$v sin npm" 'Reinstala Node.js: winget install --id OpenJS.NodeJS.LTS -e' }
    Nuevo-Resultado 'node' $nombre 'ok' "$v"
}

function Comprobar-Claude {
    $exe = Ruta-Claude
    if (-not $exe) { return Nuevo-Resultado 'claude' 'Claude Code' 'falta' 'no está' 'irm https://claude.ai/install.ps1 | iex' }
    $v = ((Ejecutar $exe @('--version')).Lineas | Select-Object -First 1) -replace '\s*\(Claude Code\)', ''
    Nuevo-Resultado 'claude' 'Claude Code' 'ok' $v
}

function Comprobar-Cuenta {
    $nombre = 'Cuenta de Claude Max (5x o superior)'
    $exe = Ruta-Claude
    if (-not $exe) { return Nuevo-Resultado 'cuenta' $nombre 'falta' 'sin Claude Code' 'Instala Claude Code y entra con tu cuenta de Claude Max.' }
    $estado = Json-DeTexto (Ejecutar $exe @('auth', 'status', '--json')).Texto
    if (-not $estado) { return Nuevo-Resultado 'cuenta' $nombre 'aviso' 'no se pudo leer' 'Abre una terminal, escribe claude y entra con tu cuenta de Claude Max.' }
    if (-not $estado.loggedIn) { return Nuevo-Resultado 'cuenta' $nombre 'falta' 'sin sesión iniciada' 'Abre una terminal, escribe claude y entra con tu cuenta de Claude Max (5x o superior).' }
    switch ("$($estado.subscriptionType)") {
        'max' { return Nuevo-Resultado 'cuenta' $nombre 'ok' 'sesión iniciada con Claude Max' }
        'pro' { return Nuevo-Resultado 'cuenta' $nombre 'falta' 'plan Pro' 'Drazo Pro necesita Claude Max 5x o superior: con Pro se queda corto. Cambia de plan en claude.ai.' }
        default { return Nuevo-Resultado 'cuenta' $nombre 'aviso' "plan «$($estado.subscriptionType)» ($($estado.authMethod))" 'Drazo Pro está pensado para Claude Max 5x o superior.' }
    }
}

function Comprobar-Ffmpeg {
    $nombre = 'ffmpeg con libx264 y zscale'
    $exe = Buscar-Comando 'ffmpeg'
    if (-not $exe) { return Nuevo-Resultado 'ffmpeg' $nombre 'falta' 'no está' 'winget install --id Gyan.FFmpeg -e' }
    $ver = Ejecutar $exe @('-hide_banner', '-version')
    $primera = (($ver.Lineas | Select-Object -First 1) -replace '^ffmpeg version\s+', '') -replace '\s+Copyright.*$', ''
    $faltan = @()
    if ($ver.Texto -notmatch '--enable-libx264') { $faltan += 'libx264' }
    if ((Ejecutar $exe @('-hide_banner', '-filters')).Texto -notmatch '\szscale\s') { $faltan += 'zscale' }
    if (-not (Buscar-Comando 'ffprobe')) { $faltan += 'ffprobe' }
    if ($faltan.Count) { return Nuevo-Resultado 'ffmpeg' $nombre 'falta' "$primera sin $($faltan -join ', ') ($exe)" 'Instala la versión completa (winget install --id Gyan.FFmpeg -e) y quita del PATH el ffmpeg anterior.' }
    Nuevo-Resultado 'ffmpeg' $nombre 'ok' $primera
}

function Comprobar-Python {
    $nombre = 'Python 3.10 o superior'
    $base = Buscar-PythonBase
    if ($base) { return Nuevo-Resultado 'python' $nombre 'ok' "$($base.Version) ($($base.Exe))" }
    if (Test-Path -LiteralPath $DrazoPython) { return Nuevo-Resultado 'python' $nombre 'aviso' 'no hay Python en el sistema, pero el entorno de Drazo existe' 'Solo hace falta para rehacer el entorno: winget install --id Python.Python.3.12 -e' }
    Nuevo-Resultado 'python' $nombre 'falta' 'no está (los de conda no sirven)' 'winget install --id Python.Python.3.12 -e'
}

function Comprobar-Entorno {
    $nombre = 'Entorno de Python de Drazo'
    if (-not (Test-Path -LiteralPath $DrazoPython)) { return Nuevo-Resultado 'venv' $nombre 'falta' "no existe $DrazoVenv" 'Lo crea el instalador de Drazo.' }
    $r = Ejecutar $DrazoPython @('-X', 'utf8', (Join-Path $DrazoScripts 'comprobar-python.py'))
    $py = $r.Lineas | Where-Object { $_ -like 'PYTHON *' } | Select-Object -First 1
    if (-not $py) { return Nuevo-Resultado 'venv' $nombre 'falta' 'su Python no arranca' 'Vuelve a ejecutar el instalador de Drazo: rehace el entorno.' }
    $mal = @($r.Lineas | Where-Object { $_ -like 'MAL *' } | ForEach-Object { ($_ -split ' ', 3)[1] })
    $bien = @($r.Lineas | Where-Object { $_ -like 'OK *' } | ForEach-Object { $p = $_ -split ' '; "$($p[1]) $($p[2])" })
    $version = ($py -split ' ')[1]
    if ($mal.Count) { return Nuevo-Resultado 'venv' $nombre 'falta' "Python $version; fallan: $($mal -join ', ')" 'Vuelve a ejecutar el instalador de Drazo: reinstala los paquetes.' }
    Nuevo-Resultado 'venv' $nombre 'ok' "Python $version · $($bien -join ', ')"
}

function Comprobar-Playwright {
    $nombre = 'playwright-core de Drazo'
    $pj = Join-Path $DrazoNode 'node_modules\playwright-core\package.json'
    if (-not (Test-Path -LiteralPath $pj)) { return Nuevo-Resultado 'playwright' $nombre 'falta' "no está en $DrazoNode" 'Lo instala el instalador de Drazo (solo para Drazo, no global).' }
    Nuevo-Resultado 'playwright' $nombre 'ok' ((Get-Content -LiteralPath $pj -Raw | ConvertFrom-Json).version)
}

function Comprobar-Chrome {
    $exe = Ruta-Chrome
    if (-not $exe) { return Nuevo-Resultado 'chrome' 'Google Chrome' 'falta' 'no está' 'winget install --id Google.Chrome -e (o descárgalo de google.com/chrome)' }
    Nuevo-Resultado 'chrome' 'Google Chrome' 'ok' ((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion)
}

function Comprobar-NavegadorHF {
    $nombre = 'Navegador de HyperFrames'
    $exe = Ruta-NavegadorHyperFrames
    if (-not $exe) { return Nuevo-Resultado 'navegador' $nombre 'falta' 'no está' 'npx hyperframes browser ensure' }
    Nuevo-Resultado 'navegador' $nombre 'ok' ("chrome-headless-shell " + (Leer-Version $exe))
}

function Comprobar-SkillsHF {
    $nombre = 'Skills públicas de HyperFrames'
    $dir = Join-Path (Carpeta-ConfigClaude) 'skills'
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'hyperframes\SKILL.md'))) { return Nuevo-Resultado 'skills' $nombre 'falta' "no están en $dir" 'npx skills add heygen-com/hyperframes -g -a claude-code' }
    $n = @(Get-ChildItem -LiteralPath $dir -Directory -Filter 'hyperframes*').Count
    Nuevo-Resultado 'skills' $nombre 'ok' "$n skills hyperframes* en $dir"
}

function Comprobar-Fuentes {
    $nombre = 'Fuentes de las plantillas'
    $instaladas = Familias-Instaladas
    $faltan = @(Leer-Fuentes | Select-Object -ExpandProperty Familia -Unique | Where-Object {
        $patron = '^' + [regex]::Escape($_) + '\b'
        -not ($instaladas | Where-Object { $_ -match $patron })
    })
    if ($faltan.Count) { return Nuevo-Resultado 'fuentes' $nombre 'falta' "faltan: $($faltan -join ', ')" 'Las instala el instalador de Drazo (Google Fonts, licencia OFL).' }
    Nuevo-Resultado 'fuentes' $nombre 'ok' 'Anton, Caveat, Poppins, Inter y JetBrains Mono'
}

function Comprobar-Telemetria {
    $nombre = 'Telemetría de HyperFrames apagada'
    $v = [Environment]::GetEnvironmentVariable('HYPERFRAMES_NO_TELEMETRY', 'User')
    if (-not $v) { $v = $env:HYPERFRAMES_NO_TELEMETRY }
    if ($v -eq '1') { return Nuevo-Resultado 'telemetria' $nombre 'ok' 'HYPERFRAMES_NO_TELEMETRY=1' }
    Nuevo-Resultado 'telemetria' $nombre 'falta' 'sin HYPERFRAMES_NO_TELEMETRY=1' 'La pone el instalador de Drazo (variable de usuario).'
}

function Comprobar-Tesseract {
    $nombre = "Tesseract $VersionTesseract (opcional)"
    if (-not (Test-Path -LiteralPath $TsrctRuta)) { return Nuevo-Resultado 'tesseract' $nombre 'aviso' 'no instalado' 'Opcional: el instalador de Drazo lo instala si aceptas las condiciones de Mirage.' -Opcional }
    $v = "" + (Leer-Version (Ejecutar $TsrctRuta @('--version')).Texto)
    $skills = Join-Path (Carpeta-ConfigClaude) 'skills'
    $sinSkills = @($SkillsTesseract | Where-Object { -not (Test-Path -LiteralPath (Join-Path $skills "$_\SKILL.md")) })
    $pin = Get-Content -LiteralPath (Join-Path $skills 'tesseract-video\references\cli-version.txt') -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($v -ne $VersionTesseract) { return Nuevo-Resultado 'tesseract' $nombre 'aviso' "tsrct $v (Drazo usa $VersionTesseract)" 'Reinstala Tesseract con el instalador de Drazo.' -Opcional }
    if ($sinSkills.Count) { return Nuevo-Resultado 'tesseract' $nombre 'aviso' "tsrct $v; faltan las skills $($sinSkills -join ', ')" 'Vuelve a ejecutar el instalador de Drazo y acepta Tesseract.' -Opcional }
    if ($pin -and $pin.Trim() -ne $VersionTesseract) { return Nuevo-Resultado 'tesseract' $nombre 'aviso' "tsrct $v, pero sus skills piden $($pin.Trim())" 'Vuelve a ejecutar el instalador de Drazo para alinear las skills de Tesseract.' -Opcional }
    Nuevo-Resultado 'tesseract' $nombre 'ok' "tsrct $v y sus skills" -Opcional
}

function Comprobar-Licencia {
    $nombre = 'Clave de licencia (DRAZO_LICENCIA)'
    $guardada = [Environment]::GetEnvironmentVariable('DRAZO_LICENCIA', 'User')
    $clave = if ($env:DRAZO_LICENCIA) { $env:DRAZO_LICENCIA } else { $guardada }
    if (-not $clave) { return Nuevo-Resultado 'licencia' $nombre 'falta' 'no está' 'Vuelve a ejecutar el instalador de Drazo y pega tu clave (empieza por drz_).' }
    $visible = 'drz_…' + $clave.Substring([Math]::Max(0, $clave.Length - 4))
    if (-not $clave.StartsWith('drz_')) { return Nuevo-Resultado 'licencia' $nombre 'aviso' 'no empieza por drz_' 'Revisa que pegaste la clave completa de Drazo.' }
    if (-not $env:DRAZO_LICENCIA) { return Nuevo-Resultado 'licencia' $nombre 'aviso' "$visible guardada, pero esta ventana no la ve" 'Cierra y abre la terminal y Claude Code para que la lean.' }
    Nuevo-Resultado 'licencia' $nombre 'ok' $visible
}

# Los motores de Drazo se descargan con un comando bash (curl ... | node ...) que lee $DRAZO_LICENCIA.
# Sin comillas dobles en el comando: PowerShell 5.1 las rompe al pasarlas a un programa.
function Comprobar-Bash {
    $nombre = 'Terminal Bash de Claude Code'
    $bash = Ruta-GitBash
    if (-not $bash) { return Nuevo-Resultado 'bash' $nombre 'falta' 'no hay Git Bash' 'Claude Code usa Git Bash para instalar los motores de Drazo: winget install --id Git.Git -e' }
    $r = Ejecutar $bash @('-c', 'command -v curl >/dev/null && echo curl=si || echo curl=no; command -v node >/dev/null && echo node=si || echo node=no; [ ${#DRAZO_LICENCIA} -gt 0 ] && echo clave=si || echo clave=no')
    $faltan = @()
    if ($r.Texto -notmatch 'curl=si') { $faltan += 'curl' }
    if ($r.Texto -notmatch 'node=si') { $faltan += 'node' }
    if ($faltan.Count) { return Nuevo-Resultado 'bash' $nombre 'falta' "Git Bash no encuentra: $($faltan -join ', ')" 'Vuelve a ejecutar el instalador de Drazo (Git y Node.js) y abre una terminal nueva.' }
    if ($r.Texto -notmatch 'clave=si') {
        $arreglo = if ([Environment]::GetEnvironmentVariable('DRAZO_LICENCIA', 'User')) { 'La clave está guardada, pero esta sesión no la ve: cierra Claude Code y la terminal, y vuelve a abrirlos.' } else { 'Pon tu clave con el instalador de Drazo y después cierra y vuelve a abrir Claude Code.' }
        return Nuevo-Resultado 'bash' $nombre 'falta' 'curl y node sí, pero la clave DRAZO_LICENCIA no se ve desde bash' $arreglo
    }
    Nuevo-Resultado 'bash' $nombre 'ok' 'curl, node y la clave DRAZO_LICENCIA visibles en Git Bash'
}

function Comprobar-Plugin {
    $nombre = 'Plugin drazo en Claude Code'
    $exe = Ruta-Claude
    if (-not $exe) { return Nuevo-Resultado 'plugin' $nombre 'falta' 'sin Claude Code' 'Instala Claude Code y vuelve a ejecutar el instalador de Drazo.' }
    $p = @(Json-DeTexto (Ejecutar $exe @('plugin', 'list', '--json')).Texto) | Where-Object { $_.id -eq $IdPlugin } | Select-Object -First 1
    if (-not $p) { return Nuevo-Resultado 'plugin' $nombre 'falta' 'no instalado' 'Lo instala el instalador de Drazo (claude plugin install drazo@drazo).' }
    if ($p.errors) { return Nuevo-Resultado 'plugin' $nombre 'falta' ("con errores: " + ($p.errors -join '; ')) 'Vuelve a ejecutar el instalador de Drazo; si sigue, escribe al soporte.' }
    if (-not $p.enabled) { return Nuevo-Resultado 'plugin' $nombre 'falta' "$($p.version) desactivado" 'Actívalo: claude plugin enable drazo@drazo' }
    Nuevo-Resultado 'plugin' $nombre 'ok' "versión $($p.version), ámbito $($p.scope)"
}

function Comprobar-Disco {
    $nombre = "Espacio libre (más de $DiscoMinimoGB GB)"
    $unidad = New-Object System.IO.DriveInfo (Split-Path -Qualifier $env:LOCALAPPDATA)
    $libre = [math]::Round($unidad.AvailableFreeSpace / 1GB, 1)
    $det = "$libre GB libres en $($unidad.Name)"
    if ($libre -lt $DiscoMinimoGB) { return Nuevo-Resultado 'disco' $nombre 'falta' $det 'Libera espacio: brutos, entorno de Python, navegador y renders ocupan varios GB.' }
    Nuevo-Resultado 'disco' $nombre 'ok' $det
}

function Comprobar-Memoria {
    $nombre = 'Memoria (RAM)'
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if (-not $cs) { return Nuevo-Resultado 'memoria' $nombre 'aviso' 'no se pudo leer' }
    $total = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $libre = if ($os) { [math]::Round($os.FreePhysicalMemory * 1KB / 1GB, 1) } else { '?' }
    $det = "$total GB en total, $libre GB libres ahora"
    if ($total -lt 8) { return Nuevo-Resultado 'memoria' $nombre 'aviso' $det 'Con menos de 8 GB los renders van lentos o fallan: cierra otras aplicaciones al editar.' }
    Nuevo-Resultado 'memoria' $nombre 'ok' $det
}

# Una comprobación que revienta no debe tumbar el doctor: queda como aviso con el error.
function Ejecutar-Comprobacion([string]$Funcion) {
    try {
        & $Funcion
    } catch {
        $nombre = $Funcion -replace '^Comprobar-', ''
        Nuevo-Resultado $nombre.ToLower() $nombre 'aviso' "no se pudo comprobar: $($_.Exception.Message)" 'Pasa este mensaje al soporte de ProfimaxIA.'
    }
}

# Orden de comprobación = orden de instalación.
$ComprobacionesDrazo = @(
    'Comprobar-Sistema', 'Comprobar-Winget', 'Comprobar-Git', 'Comprobar-Node', 'Comprobar-Claude', 'Comprobar-Cuenta',
    'Comprobar-Ffmpeg', 'Comprobar-Python', 'Comprobar-Entorno', 'Comprobar-Playwright', 'Comprobar-Chrome',
    'Comprobar-NavegadorHF', 'Comprobar-SkillsHF', 'Comprobar-Fuentes', 'Comprobar-Telemetria', 'Comprobar-Tesseract',
    'Comprobar-Licencia', 'Comprobar-Bash', 'Comprobar-Plugin', 'Comprobar-Disco', 'Comprobar-Memoria'
)

function Mostrar-Resultado($R) {
    $color = @{ ok = 'Green'; falta = 'Red'; aviso = 'Yellow' }[$R.Estado]
    $etiqueta = @{ ok = '  OK  '; falta = 'FALTA '; aviso = 'AVISO ' }[$R.Estado]
    Write-Host "  [$etiqueta] " -ForegroundColor $color -NoNewline
    Write-Host ("{0,-40} {1}" -f $R.Nombre, $R.Detalle)
}

# Resumen final: lo que falta (obligatorio) con su arreglo, y los avisos aparte.
function Mostrar-Arreglos($Resultados) {
    $faltan = @($Resultados | Where-Object { $_.Estado -eq 'falta' })
    $avisos = @($Resultados | Where-Object { $_.Estado -eq 'aviso' -and $_.Arreglo })
    Write-Host ''
    if ($faltan.Count -eq 0) {
        Write-Host 'Todo lo necesario está listo.' -ForegroundColor Green
    } else {
        Write-Host 'Qué falta y cómo arreglarlo:' -ForegroundColor Red
        $i = 1
        foreach ($r in $faltan) { Write-Host ("  {0}. Falta {1}: {2}" -f $i, $r.Nombre, $r.Arreglo); $i++ }
    }
    if ($avisos.Count) {
        Write-Host ''
        Write-Host 'Avisos:' -ForegroundColor Yellow
        foreach ($r in $avisos) { Write-Host ("  - {0}: {1}" -f $r.Nombre, $r.Arreglo) }
    }
}
