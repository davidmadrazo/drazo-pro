// Ajustes de usuario de Claude Code (settings.json) para Drazo: los lee y los fusiona sin tocar lo demás.
// Los usan el instalador, el doctor y la prueba del servidor; la app de escritorio lee el mismo fichero.
//
//   node ajustes-claude.mjs estado                                líneas clave=valor (la clave sale tapada)
//   node ajustes-claude.mjs registrar --licencia drz_... [--fuente-local <carpeta del repo>]
//   node ajustes-claude.mjs telemetria                            env.HYPERFRAMES_NO_TELEMETRY = "1"
//
// Antes de escribir siempre deja copia (settings.json.antes-de-drazo-<fecha>). Si el fichero no es JSON
// válido, no lo toca. Códigos: 0 bien · 1 no se pudo · 2 uso incorrecto.
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

export const ID_PLUGIN = "drazo@drazo"
export const MARKETPLACE = "drazo"
export const REPO = "davidmadrazo/drazo-pro"

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
  seccion(a, "env").CLAUDE_CODE_PLUGIN_PREFER_HTTPS = "1"
  return a
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
  if (orden !== "registrar" && orden !== "telemetria") {
    console.error("Uso: node ajustes-claude.mjs estado | registrar --licencia drz_... [--fuente-local <carpeta>] | telemetria")
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
