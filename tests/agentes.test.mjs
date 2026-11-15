// Los dos agentes del plugin (repo público): existen, su frontmatter es válido, solo llevan lo mínimo y no delatan método.
// Uso: node --test tests/agentes.test.mjs
import assert from "node:assert/strict"
import { existsSync, readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { test } from "node:test"
import { fileURLToPath } from "node:url"

const carpeta = join(dirname(fileURLToPath(import.meta.url)), "..", "plugins", "drazo", "agents")
const PREFIJO = "mcp__plugin_drazo_drazo__"
const ESPERADAS = {
  "drazo-director": ["drazo_direccion", "drazo_variantes", "drazo_encargo", "drazo_entregar"],
  "drazo-revisor": ["drazo_revisar", "drazo_encargo", "drazo_entregar"],
}
const PALABRAS_DE_METODO = ["canon", "regla", "EDI-", "GAN-"]

function leer(nombre) {
  const ruta = join(carpeta, `${nombre}.md`)
  assert.ok(existsSync(ruta), `falta ${ruta}`)
  const m = readFileSync(ruta, "utf8").replace(/\r\n/g, "\n").match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/)
  assert.ok(m, `${nombre}: sin frontmatter`)
  const campos = {}
  let lista = null
  for (const linea of m[1].split("\n")) {
    const item = linea.match(/^\s+-\s+(.+)$/)
    if (item && lista) { lista.push(item[1].trim()); continue }
    const kv = linea.match(/^([A-Za-z]+):\s*(.*)$/)
    assert.ok(kv, `${nombre}: línea de frontmatter no válida: ${linea}`)
    if (kv[2] === "") { lista = campos[kv[1]] = [] } else { lista = null; campos[kv[1]] = kv[2].trim() }
  }
  return { campos, cuerpo: m[2] }
}

for (const [nombre, herramientas] of Object.entries(ESPERADAS)) {
  test(`${nombre}: frontmatter válido`, () => {
    const { campos } = leer(nombre)
    assert.equal(campos.name, nombre)
    assert.ok(campos.description.length > 20)
    assert.ok(["opus", "sonnet"].includes(campos.model), "model: opus o sonnet")
    assert.ok(Number(campos.maxTurns) >= 10 && Number(campos.maxTurns) <= 100)
    assert.ok(Array.isArray(campos.tools) && campos.tools.length > 0)
  })

  test(`${nombre}: solo Read, Write y las herramientas MCP de Drazo que necesita`, () => {
    const { campos } = leer(nombre)
    const propias = campos.tools.filter((t) => t.startsWith(PREFIJO)).map((t) => t.slice(PREFIJO.length)).sort()
    assert.deepEqual(propias, [...herramientas].sort())
    const otras = campos.tools.filter((t) => !t.startsWith(PREFIJO)).sort()
    assert.deepEqual(otras, ["Read", "Write"])
    for (const t of campos.tools) assert.doesNotMatch(t, /Bash|Edit|Web|Agent|Task/i)
  })

  test(`${nombre}: el cuerpo no lleva método`, () => {
    const { cuerpo } = leer(nombre)
    assert.ok(cuerpo.length > 500)
    for (const p of PALABRAS_DE_METODO) assert.ok(!cuerpo.toLowerCase().includes(p.toLowerCase()), `el cuerpo contiene «${p}»`)
  })

  test(`${nombre}: lleva el protocolo (encargo como instrucciones, texto exacto, confidencialidad)`, () => {
    const { cuerpo } = leer(nombre)
    for (const frase of ["encargo: true", "al pie de la letra", "exactamente", "confidencial", "tal cual"]) {
      assert.ok(cuerpo.includes(frase), `falta «${frase}»`)
    }
  })
}
