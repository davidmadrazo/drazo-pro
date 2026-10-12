// Ajustes de usuario de Claude Code (settings.json) para Drazo: los lee y los fusiona sin tocar lo demás.
// Los usan el instalador, el doctor y la prueba del servidor; la app de escritorio lee el mismo fichero.
//
//   node ajustes-claude.mjs estado                                líneas clave=valor (la clave sale tapada)
//   node ajustes-claude.mjs registrar --licencia drz_... [--fuente-local <carpeta del repo>]
//   node ajustes-claude.mjs telemetria                            env.HYPERFRAMES_NO_TELEMETRY = "1"
//   node ajustes-claude.mjs carpeta --ruta <carpeta de Drazo>     crea videos/ y el bloque de Drazo en CLAUDE.md
//   node ajustes-claude.mjs instalar-plugin --claude <ruta de la orden claude> [--fuente-local <carpeta del repo>]
//        descarga e instala el plugin con la orden claude (la app no lo baja sola al reabrirse)
//
// Antes de escribir siempre deja copia (settings.json.antes-de-drazo-<fecha>). Si el fichero no es JSON
// válido, no lo toca. Códigos: 0 bien · 1 no se pudo · 2 uso incorrecto.
import { spawnSync } from "node:child_process"
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

export const ID_PLUGIN = "drazo@drazo"
export const MARKETPLACE = "drazo"
export const REPO = "davidmadrazo/drazo-pro"
const ESPERA_MCP_MS = 900_000

export const carpetaConfig = () => process.env.CLAUDE_CONFIG_DIR || join(homedir(), ".claude")
export const rutaAjustes = () => join(carpetaConfig(), "settings.json")
const carpetaPlugins = () => process.env.CLAUDE_CODE_PLUGIN_CACHE_DIR || join(carpetaConfig(), "plugins")
const esObjeto = (v) => v !== null && typeof v === "object" && !Array.isArray(v)

// Lanza un error con mensaje claro si el fichero existe pero no es JSON.
export function leerAjustes() {
  const ruta = rutaAjustes()
  if (!existsSync(ruta)) return {}
  const texto = readFileSync(ruta, "utf8").replace(/^﻿/, "")
  if (!texto.trim()) return {}
  try {
    const datos = JSON.parse(texto)
    if (!esObjeto(datos)) throw new Error("no es un objeto JSON")
    return datos
  } catch (err) {
    throw new Error(`${ruta} no es JSON válido (${err.message}); no se toca`)
  }
}

export const licenciaGuardada = (a) => (a?.pluginConfigs?.[ID_PLUGIN]?.options?.licencia || "").trim()

const tapar = (clave) => (clave ? `drz_…${clave.slice(-4)}` : "")

function seccion(a, nombre) {
  if (!esObjeto(a[nombre])) a[nombre] = {}
  return a[nombre]
}

export function registrar(a, { licencia, fuenteLocal }) {
  const fuente = fuenteLocal ? { source: "directory", path: resolve(fuenteLocal) } : { source: "github", repo: REPO }
  seccion(a, "extraKnownMarketplaces")[MARKETPLACE] = { source: fuente, autoUpdate: true }
  seccion(a, "enabledPlugins")[ID_PLUGIN] = true
  if (licencia) {
    const configs = seccion(a, "pluginConfigs")
    const actual = esObjeto(configs[ID_PLUGIN]) ? configs[ID_PLUGIN] : {}
    const opciones = esObjeto(actual.options) ? actual.options : {}
    configs[ID_PLUGIN] = { ...actual, options: { ...opciones, licencia } }
  }
  const env = seccion(a, "env")
  env.CLAUDE_CODE_PLUGIN_PREFER_HTTPS = "1"
  // La dirección de un vídeo tarda 3-4 min en el servidor (puede llegar a 13): que Claude Code la espere entera
  if (!(Number(env.MCP_TOOL_TIMEOUT) >= ESPERA_MCP_MS)) env.MCP_TOOL_TIMEOUT = String(ESPERA_MCP_MS)
  return a
}

// Lo lee cualquier conversación abierta en la carpeta de Drazo, también si el plugin no ha cargado.
const BLOQUE_CARPETA = `<!-- drazo -->
# Carpeta de Drazo Pro

Aquí se editan los vídeos con Drazo Pro.

- \`videos/\`: los vídeos editados. Cada versión que le enseñes al usuario y el vídeo final se guardan aquí.
- \`proyectos/\`: el trabajo de cada vídeo, una carpeta por vídeo. La crea Drazo; el usuario no necesita abrirla.
- \`marca/\`: su estilo, del onboarding.

Para editar se usan siempre las herramientas de Drazo (\`drazo_estado\`, \`drazo_empezar\`…) y su skill.

**Si en esta conversación no tienes las herramientas de Drazo, el plugin no ha cargado.** No edites por tu cuenta ni
hables de otra cosa: díselo al usuario en una frase y arréglalo así:
1. Pasa la comprobación de Drazo. Mac: \`bash ~/.local/share/drazo/instalador/instalar.sh --doctor\`. Windows:
   \`powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\\Drazo\\instalador\\instalar.ps1" -Doctor\`.
2. Si Drazo no está registrado o está sin descargar, conéctalo con el paso 5 de
   https://raw.githubusercontent.com/davidmadrazo/drazo-pro/main/INSTALAR.md (la licencia ya está guardada).
3. Pídele que cierre la app de Claude del todo (Mac: Cmd+Q; Windows: también desde el icono junto al reloj) y que la
   vuelva a abrir en esta carpeta.
<!-- /drazo -->
`

export function prepararCarpeta(ruta) {
  const carpeta = resolve(ruta)
  if (!existsSync(carpeta)) throw new Error(`no existe la carpeta ${carpeta}`)
  mkdirSync(join(carpeta, "videos"), { recursive: true })
  const fichero = join(carpeta, "CLAUDE.md")
  const actual = existsSync(fichero) ? readFileSync(fichero, "utf8") : ""
  const marca = /<!-- drazo -->[\s\S]*?<!-- \/drazo -->\n?/
  const nuevo = marca.test(actual)
    ? actual.replace(marca, BLOQUE_CARPETA)
    : actual.trim() ? `${actual.trimEnd()}\n\n${BLOQUE_CARPETA}` : BLOQUE_CARPETA
  if (nuevo !== actual) writeFileSync(fichero, nuevo, "utf8")
  return carpeta
}

function ejecutarClaude(claude, args) {
  // En Windows la orden puede ser un .cmd de npm (necesita shell) o un .ps1 con su .cmd al lado
  const orden = /\.ps1$/i.test(claude) && existsSync(claude.replace(/\.ps1$/i, ".cmd")) ? claude.replace(/\.ps1$/i, ".cmd") : claude
  const conShell = /\.(cmd|bat)$/i.test(orden)
  const comillas = (s) => (/[\s"&|<>^()]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s)
  const opciones = { env: { ...process.env, CLAUDE_CODE_PLUGIN_PREFER_HTTPS: "1" }, encoding: "utf8", input: "", timeout: 300_000 }
  const r = conShell
    ? spawnSync([orden, ...args].map(comillas).join(" "), { ...opciones, shell: true })
    : spawnSync(orden, args, opciones)
  return `${r.stdout || ""}${r.stderr || ""}${r.error ? r.error.message : ""}`.trim()
}

function resultadoJson(salida) {
  const linea = salida.split(/\r?\n/).reverse().find((l) => l.trim().startsWith("{"))
  try {
    return linea ? JSON.parse(linea) : null
  } catch {
    return null
  }
}

export function instalarPlugin({ claude, fuenteLocal }) {
  const licencia = licenciaGuardada(leerAjustes())
  const mercado = ejecutarClaude(claude, ["plugin", "marketplace", "add", fuenteLocal ? resolve(fuenteLocal) : REPO])
  const instalar = () => resultadoJson(ejecutarClaude(claude, ["plugin", "install", ID_PLUGIN, "--scope", "user", "--json", "-y",
    ...(licencia ? ["--config", `licencia=${licencia}`] : [])]))
  // El catálogo al día antes de instalar: si no, «install» no ve la versión nueva
  ejecutarClaude(claude, ["plugin", "marketplace", "update", MARKETPLACE])
  let r = instalar()
  if (r?.outcome !== "ok") {
    ejecutarClaude(claude, ["plugin", "marketplace", "update", MARKETPLACE])
    r = instalar()
  }
  let detalle = r?.message || mercado.split(/\r?\n/).pop() || "sin respuesta de la orden claude"
  // Ya instalado en una versión vieja: «install» no lo toca, se actualiza aparte (se aplica al reabrir la app)
  if (r?.outcome === "ok" && r.installedVersion && r.availableVersion && r.installedVersion !== r.availableVersion) {
    const salida = ejecutarClaude(claude, ["plugin", "update", ID_PLUGIN])
    detalle = `tenía la ${r.installedVersion} y hay la ${r.availableVersion}: ${salida.split(/\r?\n/).pop()}`
  }
  // La orden claude reescribe la entrada del marketplace: se vuelven a poner autoUpdate, env y licencia
  guardar(registrar(leerAjustes(), { licencia, fuenteLocal }))
  return { ok: r?.outcome === "ok", detalle }
}

export function guardar(a) {
  const ruta = rutaAjustes()
  mkdirSync(dirname(ruta), { recursive: true })
  let copia = ""
  if (existsSync(ruta)) {
    copia = `${ruta}.antes-de-drazo-${new Date().toISOString().replace(/[:.]/g, "-")}`
    copyFileSync(ruta, copia)
  }
  writeFileSync(ruta, JSON.stringify(a, null, 2) + "\n", "utf8")
  return copia
}

function instalado() {
  try {
    const datos = JSON.parse(readFileSync(join(carpetaPlugins(), "installed_plugins.json"), "utf8"))
    return (datos?.plugins?.[ID_PLUGIN] || []).find((r) => r?.installPath && existsSync(r.installPath)) || null
  } catch {
    return null
  }
}

export function estado() {
  const salida = { ajustes: "ok", ruta: rutaAjustes() }
  let a = {}
  try {
    a = leerAjustes()
    if (!existsSync(rutaAjustes())) salida.ajustes = "no-existe"
  } catch (err) {
    return { ...salida, ajustes: "json-invalido", detalle: err.message }
  }
  const mercado = a.extraKnownMarketplaces?.[MARKETPLACE]?.source
  const clave = licenciaGuardada(a)
  const registro = instalado()
  return {
    ...salida,
    marketplace: mercado ? "si" : "no",
    fuente: mercado ? (mercado.repo || mercado.path || mercado.url || "?") : "",
    activado: a.enabledPlugins?.[ID_PLUGIN] === true ? "si" : "no",
    licencia: clave ? "si" : "no",
    licencia_tapada: tapar(clave),
    licencia_formato: clave.startsWith("drz_") ? "si" : "no",
    telemetria: a.env?.HYPERFRAMES_NO_TELEMETRY === "1" ? "si" : "no",
    https: a.env?.CLAUDE_CODE_PLUGIN_PREFER_HTTPS === "1" ? "si" : "no",
    espera_mcp: Number(a.env?.MCP_TOOL_TIMEOUT) >= ESPERA_MCP_MS ? "si" : "no",
    descargado: registro || mercado?.source === "directory" ? "si" : "no",
    version: registro?.version || "",
  }
}

function principal(argv) {
  const [orden, ...resto] = argv
  const valor = (nombre) => {
    const i = resto.indexOf(nombre)
    return i >= 0 ? resto[i + 1] : undefined
  }
  if (orden === "estado") {
    for (const [k, v] of Object.entries(estado())) console.log(`${k}=${v}`)
    return 0
  }
  if (orden === "instalar-plugin") {
    const claude = valor("--claude")
    if (!claude) {
      console.error("Falta --claude <ruta de la orden claude>.")
      return 2
    }
    try {
      const r = instalarPlugin({ claude, fuenteLocal: valor("--fuente-local") })
      console.log(r.ok ? `Drazo descargado e instalado en Claude: ${r.detalle}` : `No se pudo instalar el plugin: ${r.detalle}`)
      return r.ok ? 0 : 1
    } catch (err) {
      console.error(`No se pudo instalar el plugin: ${err.message}`)
      return 1
    }
  }
  if (orden === "carpeta") {
    try {
      const carpeta = prepararCarpeta(valor("--ruta") || process.cwd())
      console.log(`Carpeta de Drazo lista: ${join(carpeta, "videos")} y las instrucciones en ${join(carpeta, "CLAUDE.md")}`)
      return 0
    } catch (err) {
      console.error(`No se pudo preparar la carpeta: ${err.message}`)
      return 1
    }
  }
  if (orden !== "registrar" && orden !== "telemetria") {
    console.error("Uso: node ajustes-claude.mjs estado | registrar --licencia drz_... [--fuente-local <carpeta>] | telemetria | carpeta --ruta <carpeta>")
    return 2
  }
  try {
    const a = leerAjustes()
    if (orden === "telemetria") {
      seccion(a, "env").HYPERFRAMES_NO_TELEMETRY = "1"
    } else {
      const licencia = (valor("--licencia") || "").trim() || licenciaGuardada(a)
      if (!/^drz_\S{8,}$/.test(licencia)) {
        console.error("Falta una clave de licencia válida de Drazo (empieza por drz_).")
        return 2
      }
      registrar(a, { licencia, fuenteLocal: valor("--fuente-local") })
    }
    const copia = guardar(a)
    console.log(`Ajustes guardados en ${rutaAjustes()}`)
    if (copia) console.log(`Copia de seguridad: ${copia}`)
    if (orden === "registrar") console.log(`Drazo registrado: marketplace ${MARKETPLACE}, plugin ${ID_PLUGIN}, licencia ${tapar(licenciaGuardada(a))}.`)
    return 0
  } catch (err) {
    console.error(`No se pudieron guardar los ajustes: ${err.message}`)
    return 1
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = principal(process.argv.slice(2))
}
