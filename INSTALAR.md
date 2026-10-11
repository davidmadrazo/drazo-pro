# Instalar Drazo Pro — instrucciones para Claude

Este documento es para ti, Claude. Un cliente de Drazo Pro te ha pegado este enlace y su clave de licencia (empieza por `drz_`). Lo instalas tú con tus herramientas; la persona solo aprueba los permisos en el chat.

Si lo has leído con una herramienta que resume, descárgalo entero con la terminal (`Invoke-WebRequest` en Windows, `curl` en Mac) y léelo completo antes de empezar: las órdenes tienen que ir exactas.

## Cómo trabajar

- Habla siempre en el idioma del usuario (en español si te escribe en español), también en los mensajes cortos entre una herramienta y otra. Sin jerga, rutas ni comandos salvo que los pida.
- Antes de cada bloque que instala algo, pide permiso en el chat y explica en una línea qué es. Si dice que no, sáltalo y sigue.
- La clave de licencia solo se usa en el paso 5. No la repitas entera en el chat: como mucho, sus cuatro últimos caracteres.
- No instales nada fuera de estos pasos ni toques otros ficheros. En Mac, nada de `sudo` ni Homebrew.
- Las órdenes en primer plano se cortan a los 10 minutos: lanza los bloques B y C en segundo plano (`run_in_background`) y mira su salida cada minuto o dos hasta que aparezca la línea `RESUMEN:`.
- El instalador escribe una línea por paso: `-> [paso] ok|ya estaba|falta|error|pendiente: ...`, y al final `RESUMEN: ...`. Código de salida: 0 bien · 1 algún paso no quedó bien · 2 uso incorrecto · 3 equipo no compatible · 4 esperando al usuario.
- Si un paso falla dos veces, para, cuéntale al usuario qué pasa en una frase y ofrécele escribir al soporte de ProfimaxIA (davidmadrazo@profimaxia.com).

## 1. Mira qué sistema es

- **Windows 10 u 11**: usa la herramienta PowerShell para todo este documento.
- **macOS 13 o superior**: usa la terminal Bash.
- **Otro (Linux, WSL)**: dile que Drazo Pro funciona en Windows y en Mac, y para.

## 2. Descarga el instalador

Windows:

```powershell
$d = "$env:LOCALAPPDATA\Drazo\instalador"; New-Item -ItemType Directory -Force $d | Out-Null; Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/instalar.ps1 -OutFile "$d\instalar.ps1"
```

macOS:

```bash
mkdir -p ~/.local/share/drazo/instalador && curl -fsSL https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/instalar.sh -o ~/.local/share/drazo/instalador/instalar.sh
```

Comprobación: el fichero existe y no está vacío. En el resto del documento, **INSTALAR** quiere decir:

- Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\Drazo\instalador\instalar.ps1"`
- macOS: `bash ~/.local/share/drazo/instalador/instalar.sh`

## 3. Mira qué falta (no cambia nada)

Windows: `INSTALAR -SoloComprobar` · macOS: `INSTALAR --solo-comprobar`

Lee la tabla (`[ OK ]`, `[FALTA]`, `[AVISO]`) y la lista «Esto haría el instalador». Cuéntale al usuario en dos o tres frases qué tiene ya y qué falta. Si el equipo no es compatible (código 3), díselo y para.

## 4. Instala lo que falte, por bloques

Haz solo los bloques con algún paso en la lista del paso 3, en este orden, y pasa solo esos pasos:

- Windows: `INSTALAR -Si -Pasos <pasos separados por comas>`
- macOS: `INSTALAR --si --pasos <pasos separados por comas>`

**Bloque A · programas base** (`git`, `node`, `ffmpeg`, `python`; y `claude` solo si la lista lo pide).
Di algo como: «Voy a instalar los programas que usa Drazo para montar vídeos: Git, Node.js, ffmpeg (el motor de vídeo) y Python».
- Windows, avísale antes: «Windows te mostrará una o varias ventanas "¿Quieres permitir que esta aplicación haga cambios en el dispositivo?": pulsa "Sí" en cada una».
- Mac, si falta `git`: «Se abrirá una ventana de Apple para instalar las herramientas de desarrollo: pulsa "Instalar" y espera a que termine». Si el paso acaba en `pendiente` (código 4), espera a que el usuario diga que ha terminado y repite solo `git`.
- Comprobación: `-> [paso] ok` o `ya estaba` en cada uno.

**Bloque B · Python de Drazo y modelo** (`venv`, `modelo`), en segundo plano.
Di algo como: «Ahora preparo el Python de Drazo y descargo el modelo que transcribe tus vídeos: son unos 3 GB y tarda un rato. Te aviso al terminar».

**Bloque C · herramientas de montaje** (`playwright`, `chrome`, `navegador`, `skills`, `fuentes`, `telemetria`), en segundo plano.
Di algo como: «Instalo las herramientas con las que Drazo monta y revisa los vídeos: el navegador que renderiza, Google Chrome si no lo tienes, las fuentes de las plantillas y las guías de HyperFrames».

**Bloque D · Tesseract** (`tesseract`), solo si el usuario lo quiere.
Pregunta: «Tesseract es un editor de Mirage que Drazo puede usar para algunos efectos. Es opcional y tiene sus propias condiciones (https://mirage.app/legal/tesseract-terms). ¿Lo instalo?». Solo con un sí claro.

## 5. Conecta Drazo con Claude y guarda la licencia

Di algo como: «Ahora conecto Drazo con tu Claude y guardo tu clave. Solo toco los ajustes de Drazo y antes guardo una copia de tus ajustes».

- Windows: `INSTALAR -Si -Pasos registrar -Licencia <clave>`
- macOS: `INSTALAR --si --pasos registrar --licencia <clave>`

Comprobación: `-> [registrar] ok`. Si los ajustes no son JSON válido, el instalador no los toca: díselo al usuario y ofrécele el soporte.

Lo que hace este paso, por si alguna vez hay que comprobarlo a mano: fusiona en `~/.claude/settings.json` (Windows: `%USERPROFILE%\.claude\settings.json`; o en `CLAUDE_CONFIG_DIR` si existe) estas entradas, con copia de seguridad antes (`settings.json.antes-de-drazo-<fecha>`) y sin tocar lo demás:

```json
{
  "extraKnownMarketplaces": { "drazo": { "source": { "source": "github", "repo": "davidmadrazo/drazo-pro" }, "autoUpdate": true } },
  "enabledPlugins": { "drazo@drazo": true },
  "pluginConfigs": { "drazo@drazo": { "options": { "licencia": "<clave del usuario>" } } },
  "env": { "CLAUDE_CODE_PLUGIN_PREFER_HTTPS": "1" }
}
```

## 6. Comprobación final

Windows: `INSTALAR -Doctor` · macOS: `INSTALAR --doctor`

Debe salir todo en verde. Es normal que «Drazo registrado» diga «aún sin descargar»: se descarga al abrir de nuevo la app. La línea «Servidor de Drazo» confirma que la licencia funciona. Si dice «licencia inactiva» o «clave no válida», díselo al usuario con esas mismas palabras y ofrécele el soporte. Si falta algo, repite solo ese paso del bloque que toque.

## 7. Reinicia y empieza

Díselo así: «¡Listo! Cierra la app de Claude del todo y vuelve a abrirla: así carga Drazo y los programas nuevos. Después abre una conversación nueva en la pestaña Code, elige la carpeta de tus vídeos y escribe "Hola Drazo": te pedirá tu @ de Instagram y te hará unas preguntas para aprender tu estilo. O, si quieres probar ya, di "edítamelo viral". Cuando edites, pega siempre el guion del vídeo: sale mejor».

## Si después de reiniciar Drazo no responde

- Pasa el doctor (paso 6; antes, el paso 2 si el instalador ya no está).
- Si «Drazo registrado» sigue «aún sin descargar»: que el usuario pulse **+** junto al cuadro de texto, **Plugins**, **Añadir plugin** y elija **Drazo Pro**; o, si tiene Claude Code en la terminal, `claude plugin install drazo@drazo`. Después, otra vez cerrar y abrir la app.
- Si falla la licencia: pídele una clave nueva y repite el paso 5.
- En Windows, si Claude no encuentra `node`, `ffmpeg` o `git` justo después de instalarlos, es normal hasta cerrar y abrir la app (el instalador ya los ve).
