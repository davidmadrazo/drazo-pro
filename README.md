# Drazo Pro

Drazo Pro edita tus vídeos dentro de Claude, en tu propio ordenador. Le dices «edítame el vídeo» y Claude lo monta siguiendo el método de Drazo: cortes, subtítulos con tu estilo, ritmo, sonido y render final.

## Qué necesitas

- Un ordenador con **Windows 10 u 11** (64 bits) o un **Mac con macOS 13** o superior.
- Una suscripción a **Claude Max 5x o superior**. Con el plan Pro no llega.
- Tu **clave de licencia de Drazo**. Empieza por `drz_` y te la enviamos al darte de alta.
- Unos **10 GB libres** en el disco y, mejor, 16 GB de memoria (mínimo 8).

## Instalar sin tocar la terminal

1. Descarga la **app de escritorio de Claude** desde [claude.com/download](https://claude.com/download), instálala como cualquier programa y entra con tu cuenta de Claude Max.
2. En la app, abre la pestaña **Code** y elige una carpeta, por ejemplo una carpeta «Drazo» dentro de Documentos.
3. Pega este mensaje en el chat, con tu clave al final:

   > Instala Drazo Pro siguiendo https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/INSTALAR.md. Mi clave de licencia es drz_…

4. Claude lo instala todo. Tú solo apruebas los permisos que te pida en el chat. En Windows verás también ventanas «¿Quieres permitir que esta aplicación haga cambios?»: pulsa **Sí**. En Mac puede abrirse una ventana de Apple para instalar las herramientas de desarrollo: pulsa **Instalar**.
5. Cuando Claude te lo diga, **cierra la app del todo y vuelve a abrirla**.

## Tu primer vídeo

1. Abre una conversación nueva en la pestaña **Code** y elige la carpeta de tus vídeos.
2. Escribe **«Hola Drazo»**. La primera vez te pedirá tu @ de Instagram y te hará unas preguntas, una a una, para aprender tu estilo (letra, colores, subtítulos, ritmo). Solo se hace una vez.
3. Después, dile **«edítame el vídeo»**. **Pega siempre el guion del vídeo: sale mejor.**

¿Quieres probar antes de las preguntas? Di **«edítamelo viral»**: Drazo edita con un estilo de prueba y, al entregarte el vídeo, te ofrece hacer el onboarding.

Cuando quieras, puedes decir «rehaz mi onboarding», «cambia mis colores» o «cambia mi letra».

Claude te pedirá permiso para usar las herramientas de Drazo y para ejecutar los comandos con los que descarga sus motores: elige la opción de permitirlo siempre para que no te pregunte cada vez.

### Tus vídeos no salen de tu ordenador

La transcripción, el montaje y el render se hacen en tu equipo. Los reels que nos enseñes para aprender tu estilo también se descargan y se analizan en tu ordenador. Al servidor de Drazo solo viaja texto, como la transcripción de lo que dices, para preparar la dirección del vídeo.

### Qué se instala

- Git, Node.js, ffmpeg (la versión completa), Google Chrome y Python con un entorno propio de Drazo, que no toca tus otros programas. En Mac, sin contraseña de administrador: todo va en la carpeta de Drazo.
- El modelo de transcripción (large-v3-turbo, unos 1,6 GB), para que la primera transcripción no tarde ni se corte.
- HyperFrames, el motor con el que se montan los vídeos (su navegador y sus guías).
- Las fuentes libres de las plantillas: Anton, Caveat, Poppins, Inter y JetBrains Mono (de Google Fonts, licencia OFL).
- Opcional: Tesseract, de Mirage. Si lo instalas, aceptas sus condiciones de uso.
- El plugin de Drazo para Claude, conectado con tu clave.

Lo de Drazo se guarda en su propia carpeta: `%LOCALAPPDATA%\Drazo` en Windows y `~/.local/share/drazo` en Mac.

## Si algo falla

1. **Pregúntale a Claude**: «comprueba mi instalación de Drazo». Pasa el doctor, que revisa tu equipo, tu clave y la conexión con Drazo, y te dice qué falta y cómo arreglarlo.
2. **Vuelve a pegar el mensaje de instalación**: Claude comprueba todo otra vez e instala solo lo que falte.

| Qué ves | Qué hacer |
|---|---|
| «Licencia inactiva» o «clave no válida» | Tu suscripción no está activa o la clave no es correcta. Escríbenos. |
| Claude no conoce Drazo | Cierra la app del todo y vuelve a abrirla. Si sigue, vuelve a pegar el mensaje de instalación. |
| Claude no consigue descargar un motor de Drazo | Cierra la app y vuelve a abrirla. Si sigue, pídele que compruebe la instalación. |
| El render va muy lento o se corta | Cierra otros programas pesados y comprueba que tienes más de 10 GB libres. |

## Contacto

Soporte de **ProfimaxIA**: escríbenos a davidmadrazo@profimaxia.com o por el WhatsApp de soporte que recibiste al darte de alta. Si nos mandas lo que dice el doctor, lo resolvemos antes.

## Desinstalar

Pídele a Claude: «Desinstala Drazo Pro: quita sus entradas de mis ajustes de Claude (extraKnownMarketplaces.drazo, enabledPlugins drazo@drazo y pluginConfigs drazo@drazo) con copia de seguridad, y borra la carpeta de Drazo». En Mac, que quite también las líneas «Drazo Pro» de `~/.zshenv` y `~/.zshrc`.

## Alternativa: instalar desde la terminal

Si prefieres hacerlo tú, el instalador te pregunta antes de cada paso y te pide la clave al final.

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/instalar.ps1 -OutFile "$env:TEMP\instalar-drazo.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\instalar-drazo.ps1"
```

Mac (Terminal):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/instalar.sh)"
```

Para ver qué falta sin cambiar nada, añade `-SoloComprobar` al final del comando de Windows, o `-- --solo-comprobar` al final del de Mac.
