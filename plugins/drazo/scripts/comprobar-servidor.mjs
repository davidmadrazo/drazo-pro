// Comprueba que el servidor de Drazo responde a drazo_estado con la licencia de este equipo.
// Usa la misma URL que el plugin (../.mcp.json). Salida: una línea de resumen y, si hay, el detalle.
// Códigos: 0 responde bien · 1 responde pero rechaza (licencia u otro error) · 2 no disponible · 3 sin clave.
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const URL_POR_DEFECTO = "https://drazo.vercel.app/api/mcp"
const HERRAMIENTAS = [
  "drazo_estado", "drazo_onboarding", "drazo_marca", "drazo_empezar",
  "drazo_guia", "drazo_motor", "drazo_direccion", "drazo_revisar",
]
const PROTOCOLO = "2025-06-18"

// Se lanza para terminar; no se usa process.exit porque en Windows rompe Node con fetch a medio cerrar.
class Fin extends Error {
  constructor(codigo, resumen, detalle) {
    super(resumen)
    this.codigo = codigo
    this.detalle = detalle
  }
}

function urlDelPlugin() {
  try {
    const ruta = join(dirname(fileURLToPath(import.meta.url)), "..", ".mcp.json")
    return JSON.parse(readFileSync(ruta, "utf8")).mcpServers.drazo.url || URL_POR_DEFECTO
  } catch {
    return URL_POR_DEFECTO
  }
}

// En Streamable HTTP la respuesta puede llegar como JSON o como eventos SSE.
function leerRespuesta(tipo, texto, id) {
  if (!texto) return null
  if (!tipo.includes("text/event-stream")) {
    try { return JSON.parse(texto) } catch { return null }
  }
  for (const evento of texto.split(/\r?\n\r?\n/)) {
    const datos = evento.split(/\r?\n/).filter((l) => l.startsWith("data:")).map((l) => l.slice(5).trim()).join("\n")
    if (!datos) continue
    try {
      const msg = JSON.parse(datos)
      if (msg.id === id) return msg
    } catch { /* evento que no es JSON-RPC */ }
  }
  return null
}

function textoDeError(cuerpo, texto) {
  const e = cuerpo?.error
  if (typeof e === "string") return e
  if (e?.message) return e.message
  return cuerpo?.message || texto || ""
}

const url = urlDelPlugin()
const clave = (process.env.DRAZO_LICENCIA || "").trim()
let sesion = null
let siguienteId = 1

async function llamar(metodo, params, esNotificacion = false) {
  const cuerpo = { jsonrpc: "2.0", method: metodo, ...(params ? { params } : {}) }
  const id = esNotificacion ? null : siguienteId++
  if (id !== null) cuerpo.id = id
  const cabeceras = {
    "Content-Type": "application/json",
    Accept: "application/json, text/event-stream",
    Authorization: `Bearer ${clave}`,
    "MCP-Protocol-Version": PROTOCOLO,
  }
  if (sesion) cabeceras["Mcp-Session-Id"] = sesion
  let res
  try {
    res = await fetch(url, { method: "POST", headers: cabeceras, body: JSON.stringify(cuerpo), signal: AbortSignal.timeout(60000) })
  } catch (err) {
    throw new Fin(2, `No se pudo conectar con el servidor de Drazo (${url}).`, err?.cause?.code || err?.message)
  }
  sesion = res.headers.get("mcp-session-id") || sesion
  const tipo = res.headers.get("content-type") || ""
  const texto = await res.text()
  return { estado: res.status, mensaje: id === null ? null : leerRespuesta(tipo, texto, id), texto }
}

function resultado(r, paso) {
  if (r.estado === 401 || r.estado === 403) {
    let cuerpo = null
    try { cuerpo = JSON.parse(r.texto) } catch { /* no es JSON */ }
    const motivo = textoDeError(cuerpo, r.texto)
    if (cuerpo?.jsonrpc) throw new Fin(1, `El servidor de Drazo rechaza la clave (${r.estado}).`, motivo)
    throw new Fin(2, `El servidor respondió ${r.estado} sin respuesta MCP: puede que el servidor de Drazo aún no esté listo, o que la clave no sea válida.`, motivo)
  }
  if (r.estado === 404) throw new Fin(2, `El servidor de Drazo aún no está publicado en ${url} (404).`)
  if (r.estado >= 500) throw new Fin(2, `El servidor de Drazo falla ahora mismo (${r.estado}). Prueba más tarde.`, r.texto)
  if (!r.mensaje) throw new Fin(2, `Respuesta inesperada del servidor en ${paso} (${r.estado}).`, r.texto)
  if (r.mensaje.error) throw new Fin(1, `El servidor de Drazo devolvió un error en ${paso}.`, textoDeError(r.mensaje, r.texto))
  return r.mensaje.result
}

async function principal() {
  if (!clave) throw new Fin(3, "No hay clave de licencia (variable DRAZO_LICENCIA): no se puede probar el servidor.")
  const inicio = resultado(await llamar("initialize", {
    protocolVersion: PROTOCOLO,
    capabilities: {},
    clientInfo: { name: "drazo-doctor", version: "0.1.0" },
  }), "initialize")
  await llamar("notifications/initialized", undefined, true)

  const lista = resultado(await llamar("tools/list", {}), "tools/list")
  const nombres = (lista?.tools || []).map((t) => t.name)
  const faltan = HERRAMIENTAS.filter((n) => !nombres.includes(n))

  const estado = resultado(await llamar("tools/call", { name: "drazo_estado", arguments: {} }), "drazo_estado")
  const texto = (estado?.content || []).filter((c) => c.type === "text").map((c) => c.text).join("\n")

  if (sesion) {
    await fetch(url, { method: "DELETE", headers: { Authorization: `Bearer ${clave}`, "Mcp-Session-Id": sesion }, signal: AbortSignal.timeout(5000) }).catch(() => {})
  }
  const servidor = inicio?.serverInfo ? `${inicio.serverInfo.name} ${inicio.serverInfo.version || ""}`.trim() : "servidor MCP"
  const aviso = faltan.length ? ` Faltan herramientas en el servidor: ${faltan.join(", ")}.` : ""
  if (estado?.isError) throw new Fin(1, `El servidor de Drazo responde (${servidor}), pero drazo_estado devuelve un error.${aviso}`, texto)
  throw new Fin(0, `El servidor de Drazo responde (${servidor}) y acepta tu clave.${aviso}`, texto)
}

try {
  await principal()
} catch (err) {
  const fin = err instanceof Fin ? err : new Fin(2, "Fallo inesperado al probar el servidor de Drazo.", err?.stack || String(err))
  console.log(fin.message)
  if (fin.detalle) console.log(String(fin.detalle).trim().slice(0, 600))
  process.exitCode = fin.codigo
}
