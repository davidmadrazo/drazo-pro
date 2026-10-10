# Drazo Pro

Drazo Pro edita tus vídeos dentro de Claude Code, en tu propio ordenador. Le dices «edítame el vídeo» y Claude lo monta siguiendo el método de Drazo: cortes, subtítulos con tu estilo, ritmo, sonido y render final.

## Qué necesitas

- Un ordenador con **Windows 10 u 11** (64 bits) o un **Mac con macOS 13** o superior.
- **Claude Code con una suscripción a Claude Max 5x o superior.** Con el plan Pro no llega.
- Tu **clave de licencia de Drazo**. Empieza por `drz_` y te la enviamos al darte de alta.
- Unos **10 GB libres** en el disco y, mejor, 16 GB de memoria (mínimo 8).
- Internet durante la instalación.

## Instalar (un solo comando)

El instalador comprueba tu ordenador y te pregunta antes de instalar cada cosa. Si algo ya lo tienes, lo deja como está.

### Windows

1. Abre **PowerShell**: pulsa Inicio, escribe `PowerShell` y pulsa Intro.
2. Copia este comando, pégalo en PowerShell y pulsa Intro:

   ```powershell
   irm https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/instalar.ps1 -OutFile "$env:TEMP\instalar-drazo.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\instalar-drazo.ps1"
   ```

3. Contesta a cada pregunta (Intro es «sí»). Windows puede pedirte permiso para instalar algunos programas: acepta.
4. Cuando te pida la clave, pégala y pulsa Intro. Al pegarla no se ve nada: es normal.

### Mac

1. Abre **Terminal**: pulsa Cmd + Espacio, escribe `Terminal` y pulsa Intro.
2. Copia este comando, pégalo en Terminal y pulsa Intro:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/instalar.sh)"
   ```

3. Contesta a cada pregunta (Intro es «sí»). Para instalar Homebrew te pedirá la contraseña del Mac.
4. Cuando te pida la clave, pégala y pulsa Intro. Al pegarla no se ve nada: es normal.

Al terminar, **cierra la ventana y abre una nueva** para que tu ordenador cargue la clave.

### Solo comprobar, sin instalar nada

Si quieres ver qué te falta sin tocar nada, usa estos comandos en lugar de los de arriba:

```powershell
irm https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/instalar.ps1 -OutFile "$env:TEMP\instalar-drazo.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\instalar-drazo.ps1" -SoloComprobar
```

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/instalar.sh)" -- --solo-comprobar
```

### Qué se instala

- Claude Code, Node.js, Git, Google Chrome y ffmpeg (la versión completa).
- Python con un entorno propio de Drazo, que no toca tus otros programas.
- El modelo de transcripción (large-v3-turbo, unos 1,6 GB), para que la primera transcripción no tarde ni se corte.
- HyperFrames, el motor con el que se montan los vídeos (su navegador y sus skills públicas).
- Las fuentes libres de las plantillas: Anton, Caveat, Poppins, Inter y JetBrains Mono (de Google Fonts, licencia OFL).
- Opcional: Tesseract, de Mirage. Si lo instalas, aceptas sus condiciones de uso.
- El plugin de Drazo para Claude Code, conectado con tu clave.

Lo de Drazo se guarda en su propia carpeta: `%LOCALAPPDATA%\Drazo` en Windows y `~/.local/share/drazo` en Mac.

## Tu primer vídeo

1. Pon el vídeo sin editar (el bruto) en una carpeta.
2. Abre una terminal en esa carpeta:
   - **Windows**: abre la carpeta en el Explorador, escribe `powershell` en la barra de direcciones y pulsa Intro.
   - **Mac**: en Terminal escribe `cd ` (con un espacio), arrastra la carpeta a la ventana y pulsa Intro.
3. Escribe `claude` y pulsa Intro. La primera vez te pedirá entrar con tu cuenta de Claude Max.
4. Dile: **«edítame el vídeo»**.

**La primera vez**, Drazo te hará unas preguntas sobre ti y tu marca, una a una, y te pedirá enlaces a algunos de tus reels para aprender tu estilo (letra, colores, subtítulos, ritmo). Solo se hace una vez. Cuando quieras, puedes decir «rehaz mi onboarding» o «cambia mis colores» o «cambia mi letra».

Claude te pedirá permiso para usar las herramientas de Drazo y para ejecutar los comandos con los que descarga los motores de Drazo: elige la opción de permitirlo siempre para que no te pregunte cada vez.

### Tus vídeos no salen de tu ordenador

La transcripción, el montaje y el render se hacen en tu equipo. Los reels que nos enseñes para aprender tu estilo también se descargan y se analizan en tu ordenador. Al servidor de Drazo solo viaja texto, como la transcripción de lo que dices, para preparar la dirección del vídeo.

## Si algo falla

1. **Vuelve a ejecutar el instalador.** Comprueba todo otra vez e instala solo lo que falte.
2. **Pásale el doctor.** Dentro de Claude Code, dile «comprueba mi instalación de Drazo». El doctor revisa tu equipo, tu clave y la conexión con Drazo, y termina con una lista de lo que falta y cómo arreglarlo.

Problemas frecuentes:

| Qué ves | Qué hacer |
|---|---|
| «Licencia inactiva» o «clave no válida» | Tu suscripción no está activa o la clave no es correcta. Escríbenos. |
| Claude no encuentra las herramientas de Drazo | Cierra la terminal, abre una nueva y vuelve a escribir `claude`. Si sigue, vuelve a ejecutar el instalador. |
| Claude no consigue descargar un motor de Drazo | Cierra Claude Code y la terminal y vuelve a abrirlos: la clave se lee al abrir. Si sigue, pásale el doctor. |
| `claude` no se reconoce como comando | Abre una terminal nueva. Si sigue, vuelve a ejecutar el instalador. |
| Windows dice que la ejecución de scripts está deshabilitada | Usa el comando de instalación tal cual: ya incluye el permiso para ese único script. |
| El render va muy lento o se corta | Cierra otros programas pesados y comprueba que tienes más de 10 GB libres. |

## Contacto

Soporte de **ProfimaxIA**: escríbenos a davidmadrazo@profimaxia.com o por el WhatsApp de soporte que recibiste al darte de alta. Si nos mandas lo que dice el doctor, lo resolvemos antes.

## Desinstalar

En una terminal: `claude plugin uninstall drazo@drazo` y `claude plugin marketplace remove drazo`. Después borra la carpeta de Drazo y la clave: en Windows, la variable de usuario `DRAZO_LICENCIA`; en Mac, las líneas «Drazo Pro» de `~/.zshenv` y `~/.zshrc`.
