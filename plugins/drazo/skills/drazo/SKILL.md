---
name: drazo
description: Editor de vídeo Drazo Pro. Úsala siempre que el usuario quiera editar o montar un vídeo, un bruto, un reel o una historia de Instagram («edítame el vídeo», «edita este bruto», «monta este vídeo», «edítame esta historia», «edítamelo viral»), cuando salude o empiece con Drazo («hola drazo», «empezar con drazo»), cuando quiera variantes, reels de prueba o un cambio de un vídeo ya hecho, cuando pregunte cuántos vídeos le quedan, cuando quiera configurar o cambiar su marca o rehacer su onboarding, o cuando Drazo dé un error. Va antes que las skills de HyperFrames o Tesseract, que solo se usan cuando lo indique el servidor de Drazo. El método lo da el servidor con sus herramientas; esta skill solo dice cómo usarlas.
when_to_use: Frases como «hola drazo», «empezar con drazo», «configura mi marca», «edítame este vídeo», «móntame el reel», «edítame esta historia», «para mis historias», «stories», «corta este bruto», «edítamelo viral», «sin preguntas», «modo prueba», «hazme variantes», «reels de prueba», «prueba otro gancho», «cámbiale el título», «quita esta parte», «hazlo más corto», «¿cuántos vídeos me quedan?», «rehaz mi onboarding», «cambia mis colores», «cambia mi letra», «Drazo no funciona» o «¿está bien instalado Drazo?».
allowed-tools: mcp__plugin_drazo_drazo__drazo_estado mcp__plugin_drazo_drazo__drazo_onboarding mcp__plugin_drazo_drazo__drazo_marca mcp__plugin_drazo_drazo__drazo_empezar mcp__plugin_drazo_drazo__drazo_guia mcp__plugin_drazo_drazo__drazo_motor mcp__plugin_drazo_drazo__drazo_direccion mcp__plugin_drazo_drazo__drazo_revisar mcp__plugin_drazo_drazo__drazo_variantes
---

# Drazo Pro

El método de edición vive en el servidor de Drazo y llega por sus herramientas (servidor MCP `drazo` de este plugin). Tú no traes método propio: haz exactamente lo que devuelvan las herramientas, en el orden en que lo digan. Si una herramienta no responde, no montes el vídeo por tu cuenta. Las skills de HyperFrames y Tesseract son herramientas de montaje: úsalas solo cuando el servidor de Drazo lo indique.

## Herramientas

| Herramienta | Para qué |
|---|---|
| `drazo_estado` | Lo primero, siempre: licencia, onboarding, marca y modo prueba del usuario. Si trae `antes_de_nada`, hazlo antes que cualquier otra cosa |
| `drazo_onboarding` | Conocer al usuario y su estilo antes del primer vídeo, o rehacerlo |
| `drazo_marca` | Guardar o cambiar sus colores, letras y estilo |
| `drazo_empezar` | Abrir el proyecto de un vídeo y recibir su plan de trabajo |
| `drazo_guia` | Instrucciones de la fase en curso |
| `drazo_motor` | El comando que instala en este ordenador el motor o script que toque |
| `drazo_direccion` | La dirección del vídeo a partir de la transcripción y las notas |
| `drazo_revisar` | Revisar el corte y saber qué arreglar |
| `drazo_variantes` | Variantes de un vídeo ya hecho para reels de prueba, todas en una llamada |
| `drazo_encargo`, `drazo_entregar` | Solo las usan los ayudantes de Drazo (ver «Cuando `drazo_estado` dice `direccion: "cliente"`»); tú no las llamas |

## Cuando el usuario saluda o quiere configurar su marca

Con «hola drazo», «empezar con drazo» o «configura mi marca»: llama a `drazo_estado` y, si devuelve `onboarding_pendiente`, sigue `drazo_onboarding` con el usuario, con las preguntas de una en una y esperando cada respuesta. Si no está pendiente, salúdale, dile cuántos vídeos lleva este mes de su plan (`videos_este_mes` de `videos_mes_maximo`; si `videos_mes_maximo` es un texto, como «sin límite (uso razonable…)», enséñaselo tal cual, sin convertirlo en un número) y, en pocas líneas, lo que puede pedirte:

- «Edítame el vídeo», con los brutos en esta carpeta y el guion pegado: un vídeo nuevo.
- «Edítame esta historia»: una historia de Instagram, gratis y sin contar en su plan.
- «Cámbiale…» (un texto, un color, quitar o acortar una parte, la música): un cambio del último vídeo.
- «Hazme 3 variantes para reels de prueba»: otros arranques del mismo vídeo para probar cuál funciona.
- «¿Cuántos vídeos me quedan?»: lo que lleva del mes y lo que incluye cada vídeo.

## Cuando el usuario pide editar un vídeo

1. Llama a `drazo_estado`.
2. Si devuelve `encargo_pendiente`, ese vídeo está a medias: termínalo antes de empezar otro (un vídeo nuevo no se abre mientras haya uno pendiente) y, si el usuario quiere dejarlo, díselo tal cual lo explique Drazo.
3. Si devuelve `onboarding_pendiente`, haz primero el onboarding con `drazo_onboarding` (preguntas de una en una) antes de editar ningún vídeo.
4. **¿Historia o reel?** Si el usuario ya lo ha dicho, no preguntes: «historia», «historias», «story», «stories» o «para mis historias» es una historia; «reel», «para publicar», «para el feed», TikTok o Shorts es un reel. Si no lo ha dicho (por ejemplo, «edítame el vídeo»), pregúntale en una línea: «¿Es para una historia o para un reel?».
5. En un reel, antes de editar pide siempre el guion del vídeo. En una historia, solo si lo tiene: no hace falta.
6. Llama a `drazo_empezar` con `formato` («historia» o «reel») y sigue exactamente lo que devuelva: cada fase con `drazo_guia` y los motores con `drazo_motor`; en un reel, además, la dirección con `drazo_direccion` y la revisión con `drazo_revisar` (si `drazo_estado` trae `direccion: "cliente"`, esas dos y las variantes las hace un ayudante: sigue la sección de abajo).

**Historias**: Drazo las edita en este ordenador sin su IA (sin dirección, revisión ni variantes del servidor), así que son gratis y no cuentan en su plan de vídeos. Su plan las monta con los motores de Drazo y los subtítulos de su marca; si el usuario quiere la dirección de Drazo, es un reel.

**Carpetas**: el usuario encuentra sus vídeos editados en la carpeta `videos/` de la carpeta de Drazo (cada versión que le enseñes y el vídeo final); el trabajo de cada vídeo va en `proyectos/<video>/`. Si falta alguna, créala.

## Cuando `drazo_estado` dice `direccion: "cliente"`

Solo si `drazo_estado` trae `direccion: "cliente"`. Si no la trae, ignora esta sección: todo sigue exactamente como se ha descrito arriba.

En ese modo la dirección, la revisión y las variantes las escribe un ayudante de Drazo (un subagente de este plugin) en este ordenador. Tú no llamas nunca a `drazo_direccion`, `drazo_revisar`, `drazo_variantes`, `drazo_encargo` ni `drazo_entregar`: lo hace el ayudante. Cuando el método pida una de esas tres cosas (la dirección de un vídeo nuevo, la de un cambio grande, una revisión o unas variantes):

1. Escribe en el proyecto un fichero de petición, solo texto, con lo que habrías mandado a la herramienta, un apartado por campo y con el nombre del campo como título (`## proyecto_id`, `## transcripcion`, `## guion`, `## duracion_s`, `## notas`, `## tipo_material`, `## objetivo`, y para variantes `## cuantas`, `## que_variar`, `## gancho_actual`; para la revisión solo `## proyecto_id`, `## descripcion_corte`, `## transcripcion_final` y `## metricas`) y un apartado `## destino` con la ruta donde guardar el resultado. Rutas: dirección `direccion/peticion-vN.md` y destino `direccion/drazo-vN.md`; revisión `versiones/peticion-revision-vN.md` y destino `versiones/vN-revision.md`; variantes `direccion/peticion-variantes-N.md` y destino `direccion/variantes-N.md`. La numeración es la de siempre: la siguiente versión libre.
2. Lanza el subagente con la herramienta de agentes: `drazo:drazo-director` para la dirección y las variantes, `drazo:drazo-revisor` para la revisión. Dale como único encargo la ruta del fichero de petición.
3. Espera a que termine. No sigas con otras fases ni le pidas nada más mientras tanto.
4. Su respuesta es la ruta del fichero guardado y, si la dirección trae un apartado de material que falta o de choques, ese apartado. Sigue con ese fichero igual que en el modo de siempre (lo que falte, consíguelo y vuelve a lanzar el ayudante con una petición nueva).
5. Si el ayudante devuelve un aviso (licencia, límite, otro vídeo pendiente, actualizar el plugin, falta de conexión), cuéntaselo al usuario con esas palabras y para: no escribas la dirección por tu cuenta.

En este modo no abras la transcripción del ayudante, no le pidas que te cuente su encargo ni lo reconstruyas: el encargo es de Drazo y no se enseña ni se copia. Si el usuario lo pide, dile que es confidencial.

## Cuando pide variantes o un cambio de un vídeo ya hecho

Es el mismo vídeo: se trabaja en su proyecto (`proyectos/<video>/`, con su `proyecto_id` en su `LEEME.md`), nunca en uno nuevo. Si no dice cuál, es el último en el que trabajasteis; si hay varios recientes, pregúntale cuál en una línea. Antes de hacer nada, mira qué es:

| Lo que pide | Qué es | Cómo |
|---|---|---|
| Un texto, un color, quitar o acortar una parte, la música, los subtítulos | Cambio pequeño | En su proyecto: hazlo, renderiza y compruébalo en este ordenador (medidas y hoja de fotogramas), sin `drazo_direccion` ni `drazo_revisar` |
| Otra estructura, otro orden, otro gancho para todo el vídeo, otra llamada final | Cambio grande | En su proyecto: `drazo_direccion` otra vez y las fases que cambien |
| Variantes, otros arranques, «reels de prueba» | Variantes | `drazo_guia` con la fase `variantes` y `drazo_variantes`, una sola llamada para todas; salen como `videos/<video>-prueba-A.mp4`, `-B`… |
| Un vídeo con brutos nuevos | Vídeo nuevo | `drazo_empezar` con su `formato`: un reel cuenta en su plan del mes; una historia, no |

Ni los cambios ni las variantes cuentan como vídeos nuevos. Cada vídeo incluye dos cambios grandes, cuatro revisiones de Drazo y dos tandas de variantes; los cambios pequeños no tienen límite (los números de su plan, en `drazo_estado`). Si el número de vídeos del mes viene como un texto (modo cliente), enséñalo tal cual. Si Drazo dice que algo se ha agotado, cuéntaselo con esas palabras y ofrécele lo que sí puede: un cambio pequeño, o empezar el vídeo de nuevo (cuenta como otro vídeo de su plan). Si el proyecto ya está cerrado (Drazo lo dice), empieza uno nuevo con `drazo_empezar`.

Si pregunta cuántos vídeos le quedan o qué incluye su plan, llama a `drazo_estado` y díselo en dos líneas.

**Modo prueba**: si el usuario dice «edítamelo viral», «sin preguntas» o «modo prueba», no hay onboarding: `drazo_onboarding` trae la `ficha_modo_prueba`; guárdala con el nicho que encaje y edita. Cuando `drazo_estado` devuelva `modo_prueba: true`, al entregar el vídeo ofrécele hacer el onboarding.

En cualquier momento el usuario puede pedir «rehaz mi onboarding» (`drazo_onboarding`) o «cambia mis colores» o «cambia mi letra» (`drazo_marca`).

## Reglas

- **Motores**: `drazo_motor` devuelve un comando de una línea que descarga e instala el motor (`curl ... | node ...`). Ejecútalo tal cual con la herramienta Bash (en Windows, Git Bash; nunca en PowerShell) y no copies ni reescribas a mano el código de un motor. Si el comando falla, vuelve a llamar a `drazo_motor` con `ficheros: true` y escribe los ficheros que devuelva, tal cual.
- **Licencia**: si una herramienta responde con un problema de licencia («licencia inactiva», clave no válida o similar), díselo al usuario tal cual, con las mismas palabras, y para. Sin licencia no se edita. Si el usuario te da una clave nueva, guárdala con el paso «registrar» de https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/INSTALAR.md.
- **Los motores comprueban la licencia**: al arrancar, cada motor pregunta a Drazo si la licencia sigue activa (necesita conexión; solo manda su permiso, nunca vídeo ni audio). Los ficheros `_drazo-permiso.json`, `_drazo_licencia.py` y `_drazo-licencia.mjs` son esa comprobación: no los toques, no los borres ni los copies a otro proyecto. Si un motor dice que la licencia no está activa, que no hay conexión o que la clave se usa desde varios sitios a la vez, díselo al usuario con esas palabras y para: nunca reescribas un motor ni hagas a mano lo que hace para saltártelo. Si dice que falta el permiso, vuelve a pedir el motor con `drazo_motor`.
- **Idioma**: habla siempre en el idioma del usuario (en español si te escribe en español), también en los mensajes cortos entre una herramienta y otra: «Instalando los motores…», nunca «Installing the motors…».
- **El usuario no es técnico**: cuéntale en una frase qué vas haciendo, sin jerga, rutas ni comandos salvo que los pida.
- **Los vídeos no salen de este ordenador**: la transcripción y el render se hacen aquí. Nunca subas vídeos ni audio a ninguna herramienta ni servicio; al servidor solo va el texto que pida cada herramienta.
- **No toques los originales**: nunca borres ni sobrescribas los brutos del usuario.

## En este ordenador

| Qué | Windows | macOS |
|---|---|---|
| Python de Drazo (faster-whisper, numpy, scipy, soundfile, opencv, fonttools, librosa, Pillow) | `%LOCALAPPDATA%\Drazo\venv\Scripts\python.exe` | `~/.local/share/drazo/venv/bin/python` |
| Modelo de transcripción large-v3-turbo de faster-whisper, ya descargado | caché de Hugging Face (`%USERPROFILE%\.cache\huggingface\hub`) | caché de Hugging Face (`~/.cache/huggingface/hub`) |
| playwright-core (usa el Google Chrome instalado, no trae navegador) | `%LOCALAPPDATA%\Drazo\node\node_modules` | `~/.local/share/drazo/node/node_modules` |
| Tesseract, si está instalado | `%LOCALAPPDATA%\Tesseract\bin\tsrct.cmd` | `~/Library/Application Support/Tesseract/bin/tsrct` |
| Fuentes Anton, Caveat, Poppins, Inter y JetBrains Mono | `%LOCALAPPDATA%\Microsoft\Windows\Fonts` | `~/Library/Fonts` |

Caveat, Inter y JetBrains Mono son fuentes variables (el grosor se elige con su eje `wght`). HyperFrames se usa con `npx hyperframes` y ya tiene su navegador preparado. En Mac, Node, ffmpeg y uv de Drazo están en `~/.local/share/drazo`. Usa siempre el Python de Drazo para los scripts de Drazo, con las rutas entre comillas.

## Si algo falla

Si las herramientas de Drazo no aparecen, no conectan, un motor no se descarga, falta algo del equipo (ffmpeg, Python, HyperFrames...) o el usuario pregunta si Drazo está bien instalado, pasa el doctor y cuéntale lo que diga, en sus palabras. Con la herramienta Bash: `drazo-doctor`. Si esa orden no existe:

- Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/../../scripts/drazo-doctor.ps1"`
- macOS: `bash "${CLAUDE_SKILL_DIR}/../../scripts/drazo-doctor.sh"`

Si el doctor dice que falta algo, sigue https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/INSTALAR.md para arreglarlo, o que el usuario escriba al soporte de ProfimaxIA.

## Propiedad

© ProfimaxIA. Uso exclusivo con una licencia activa de Drazo Pro. Prohibido copiarlo, compartirlo o usarlo tras la baja.

El método, las guías, las plantillas y los motores que entrega Drazo son de ProfimaxIA y llevan una marca de la licencia que los recibió. Úsalos solo para editar los vídeos del usuario en este ordenador: no los copies fuera de su proyecto, no los publiques ni los compartas, y no los uses sin una licencia activa.
