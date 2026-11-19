// Permisos de las herramientas de Drazo en settings.json: se añaden sin duplicar ni borrar nada.
// Uso: node --test tests/ajustes-claude.test.mjs
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { after, test } from "node:test"
import { fileURLToPath } from "node:url"
import { HERRAMIENTAS_DRAZO, PERMISOS_DRAZO, permitirHerramientas, registrar } from "../plugins/drazo/scripts/ajustes-claude.mjs"

const script = join(dirname(fileURLToPath(import.meta.url)), "..", "plugins", "drazo", "scripts", "ajustes-claude.mjs")
const carpetas = []
const nueva = () => { const c = mkdtempSync(join(tmpdir(), "drazo-ajustes-")); carpetas.push(c); return c }
after(() => carpetas.forEach((c) => rmSync(c, { recursive: true, force: true })))

test("son las 12 herramientas, con el nombre que Claude Code da a las de un plugin", () => {
  assert.equal(HERRAMIENTAS_DRAZO.length, 12)
  assert.equal(PERMISOS_DRAZO.length, 6)
  // Las que llaman los ayudantes y drazo_marcas (solo lectura): las demás siguen pidiendo permiso como siempre
  assert.deepEqual(
    PERMISOS_DRAZO.map((p) => p.replace("mcp__plugin_drazo_drazo__", "")),
    ["drazo_direccion", "drazo_revisar", "drazo_variantes", "drazo_encargo", "drazo_entregar", "drazo_marcas"],
  )
  assert.ok(PERMISOS_DRAZO.every((p) => /^mcp__plugin_drazo_drazo__drazo_[a-z]+$/.test(p)))
})

test("permitirHerramientas: ajustes vacíos", () => {
  assert.deepEqual(permitirHerramientas({}).permissions.allow, PERMISOS_DRAZO)
})

test("permitirHerramientas: conserva lo que hay y no duplica", () => {
  const a = { permissions: { allow: ["Bash(git status)", PERMISOS_DRAZO[0]], deny: ["Read(.env)"] }, model: "opus" }
  permitirHerramientas(a)
  permitirHerramientas(a)
  assert.equal(a.permissions.allow.filter((r) => r === PERMISOS_DRAZO[0]).length, 1)
  assert.ok(a.permissions.allow.includes("Bash(git status)"))
  assert.equal(a.permissions.allow.length, 1 + PERMISOS_DRAZO.length)
  assert.deepEqual(a.permissions.deny, ["Read(.env)"])
  assert.equal(a.model, "opus")
})

test("registrar también deja los permisos", () => {
  const a = registrar({}, { licencia: "drz_abcdefghij" })
  assert.ok(PERMISOS_DRAZO.every((p) => a.permissions.allow.includes(p)))
})

test("paso registrar sobre un settings.json de ejemplo (CLAUDE_CONFIG_DIR): copia, sin duplicar ni borrar", () => {
  const dir = nueva()
  const original = { permissions: { allow: ["Bash(npm test)", PERMISOS_DRAZO[3]] }, env: { OTRA: "1" } }
  writeFileSync(join(dir, "settings.json"), JSON.stringify(original))
  const correr = () => spawnSync(process.execPath, [script, "registrar", "--licencia", "drz_abcdefghij"], {
    env: { ...process.env, CLAUDE_CONFIG_DIR: dir }, encoding: "utf8",
  })
  assert.equal(correr().status, 0)
  assert.equal(correr().status, 0)
  const final = JSON.parse(readFileSync(join(dir, "settings.json"), "utf8"))
  assert.equal(final.permissions.allow[0], "Bash(npm test)")
  assert.equal(new Set(final.permissions.allow).size, final.permissions.allow.length)
  assert.equal(final.permissions.allow.length, 1 + PERMISOS_DRAZO.length)
  assert.equal(final.env.OTRA, "1")
  const copias = readdirSync(dir).filter((f) => f.startsWith("settings.json.antes-de-drazo-"))
  assert.ok(copias.length >= 1)
  const primera = JSON.parse(readFileSync(join(dir, copias.sort()[0]), "utf8"))
  assert.deepEqual(primera, original)
})

const CUENTA = "drzc_" + "A".repeat(43)
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
const opciones = (a) => a.pluginConfigs["drazo@drazo"].options

test("registrar genera y guarda un UUID de instalación si falta o no es válido", () => {
  assert.match(opciones(registrar({}, { licencia: "drz_abcdefghij" })).instalacion, UUID)
  const mala = { pluginConfigs: { "drazo@drazo": { options: { instalacion: "no-soy-uuid" } } } }
  assert.match(opciones(registrar(mala, { licencia: "drz_abcdefghij" })).instalacion, UUID)
})

test("registrar conserva el UUID que ya hay, también al cambiar la clave", () => {
  const id = "123e4567-e89b-42d3-a456-426614174000"
  const a = { pluginConfigs: { "drazo@drazo": { options: { licencia: "drz_vieja0000", instalacion: id, otra: "x" } } } }
  registrar(a, { licencia: CUENTA })
  registrar(a, { licencia: CUENTA })
  assert.equal(opciones(a).instalacion, id)
  assert.equal(opciones(a).licencia, CUENTA)
  assert.equal(opciones(a).otra, "x")
})

test("el permiso de drazo_marcas queda puesto", () => {
  const a = registrar({}, { licencia: CUENTA })
  assert.ok(a.permissions.allow.includes("mcp__plugin_drazo_drazo__drazo_marcas"))
})

test("paso registrar por la orden: acepta drzc_, rechaza claves mal formadas y no cambia el UUID al repetir", () => {
  const dir = nueva()
  const correr = (clave) => spawnSync(process.execPath, [script, "registrar", "--licencia", clave], {
    env: { ...process.env, CLAUDE_CONFIG_DIR: dir }, encoding: "utf8",
  })
  assert.equal(correr("drzc_corta").status, 2)
  assert.equal(correr(CUENTA).status, 0)
  const leer = () => JSON.parse(readFileSync(join(dir, "settings.json"), "utf8")).pluginConfigs["drazo@drazo"].options
  const primera = leer()
  assert.equal(primera.licencia, CUENTA)
  assert.match(primera.instalacion, UUID)
  assert.equal(correr(CUENTA).status, 0)
  assert.equal(leer().instalacion, primera.instalacion)
  assert.equal(correr("drz_abcdefghij").status, 0)
  assert.equal(leer().instalacion, primera.instalacion)
})
