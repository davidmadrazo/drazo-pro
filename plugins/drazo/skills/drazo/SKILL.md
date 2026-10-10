---
name: drazo
description: Editor de vídeo Drazo Pro. Úsala siempre que el usuario quiera editar o montar un vídeo, un bruto o un reel («edítame el vídeo», «edita este bruto», «monta este vídeo», «hazme un reel con esta grabación»), cuando quiera rehacer su onboarding o cambiar su marca (colores, letra), o cuando Drazo dé un error. Va antes que las skills de HyperFrames o Tesseract, que solo se usan cuando lo indique el servidor de Drazo. El método lo da el servidor con sus herramientas; esta skill solo dice cómo usarlas.
when_to_use: Frases como «edítame este vídeo», «móntame el reel», «corta este bruto», «ponle subtítulos con mi estilo», «rehaz mi onboarding», «cambia mis colores», «cambia mi letra», «Drazo no funciona» o «¿está bien instalado Drazo?».
allowed-tools: mcp__plugin_drazo_drazo__drazo_estado mcp__plugin_drazo_drazo__drazo_onboarding mcp__plugin_drazo_drazo__drazo_marca mcp__plugin_drazo_drazo__drazo_empezar mcp__plugin_drazo_drazo__drazo_guia mcp__plugin_drazo_drazo__drazo_motor mcp__plugin_drazo_drazo__drazo_direccion mcp__plugin_drazo_drazo__drazo_revisar
---

# Drazo Pro

El método de edición vive en el servidor de Drazo y llega por sus herramientas (servidor MCP `drazo` de este plugin). Tú no traes método propio: haz exactamente lo que devuelvan las herramientas, en el orden en que lo digan. Si una herramienta no responde, no montes el vídeo por tu cuenta. Las skills de HyperFrames y Tesseract son herramientas de montaje: úsalas solo cuando el servidor de Drazo lo indique.

## Herramientas

| Herramienta | Para qué |
|---|---|
| `drazo_estado` | Lo primero, siempre: licencia, onboarding y marca del usuario |
| `drazo_onboarding` | Conocer al usuario y su estilo antes del primer vídeo, o rehacerlo |
| `drazo_marca` | Guardar o cambiar sus colores, letras y estilo |
| `drazo_empezar` | Abrir el proyecto de un vídeo y recibir su plan de trabajo |
| `drazo_guia` | Instrucciones de la fase en curso |
| `drazo_motor` | El comando que instala en este ordenador el motor o script que toque |
| `drazo_direccion` | La dirección del vídeo a partir de la transcripción y las notas |
| `drazo_revisar` | Revisar el corte y saber qué arreglar |

## Cuando el usuario pide editar un vídeo

1. Llama a `drazo_estado`.
2. Si devuelve `onboarding_pendiente`, llama primero a `drazo_onboarding` y síguelo con el usuario antes de editar ningún vídeo. Haz las preguntas de una en una y espera cada respuesta.
3. Llama a `drazo_empezar` y sigue exactamente lo que devuelva: cada fase con `drazo_guia`, los motores con `drazo_motor`, la dirección con `drazo_direccion` y la revisión con `drazo_revisar`.

En cualquier momento el usuario puede pedir «rehaz mi onboarding» (`drazo_onboarding`) o «cambia mis colores» o «cambia mi letra» (`drazo_marca`).

## Reglas

- **Motores**: `drazo_motor` devuelve un comando de una línea que descarga e instala el motor (`curl ... | node ...`). Ejecútalo tal cual con la herramienta Bash (en Windows, Git Bash; nunca en PowerShell). No copies ni reescribas a mano el código de un motor, y no sustituyas `$DRAZO_LICENCIA` por su valor ni la muestres. Si el comando falla, vuelve a llamar a `drazo_motor` con `ficheros: true` y escribe los ficheros que devuelva, tal cual.
- **Licencia**: si una herramienta responde con un problema de licencia («licencia inactiva», clave no válida o similar), díselo al usuario tal cual, con las mismas palabras, y para. Sin licencia no se edita.
- **Los vídeos no salen de este ordenador**: la transcripción y el render se hacen aquí. Nunca subas vídeos ni audio a ninguna herramienta ni servicio; al servidor solo va el texto que pida cada herramienta.
- **No toques los originales**: nunca borres ni sobrescribas los brutos del usuario.
- **El usuario no es técnico**: cuéntale en una frase qué vas haciendo, sin rutas ni comandos salvo que los pida.

## En este ordenador

| Qué | Windows | macOS |
|---|---|---|
| Python de Drazo (faster-whisper, numpy, scipy, soundfile, opencv, fonttools, librosa, Pillow) | `%LOCALAPPDATA%\Drazo\venv\Scripts\python.exe` | `~/.local/share/drazo/venv/bin/python` |
| playwright-core (usa el Google Chrome instalado, no trae navegador) | `%LOCALAPPDATA%\Drazo\node\node_modules` | `~/.local/share/drazo/node/node_modules` |
| Tesseract, si está instalado | `%LOCALAPPDATA%\Tesseract\bin\tsrct.cmd` | `~/Library/Application Support/Tesseract/bin/tsrct` |
| Fuentes Anton, Caveat, Poppins, Inter y JetBrains Mono | `%LOCALAPPDATA%\Microsoft\Windows\Fonts` | `~/Library/Fonts` |

Caveat, Inter y JetBrains Mono son fuentes variables (el grosor se elige con su eje `wght`). HyperFrames se usa con `npx hyperframes` y ya tiene su navegador preparado. Usa siempre el Python de Drazo para los scripts de Drazo, con las rutas entre comillas.

## Si algo falla

Si las herramientas de Drazo no aparecen, no conectan, un motor no se descarga, falta algo del equipo (ffmpeg, Python, HyperFrames...) o el usuario pregunta si Drazo está bien instalado, ejecuta el doctor y cuéntale lo que diga, en sus palabras:

- Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/drazo-doctor.ps1"`
- macOS: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/drazo-doctor.sh"`

Si el doctor dice que falta algo, el usuario puede volver a ejecutar el instalador de Drazo o escribir al soporte de ProfimaxIA.
