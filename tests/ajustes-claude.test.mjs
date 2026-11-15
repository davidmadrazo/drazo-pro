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

test("son las 11 herramientas, con el nombre que Claude Code da a las de un plugin", () => {
  assert.equal(HERRAMIENTAS_DRAZO.length, 11)
  assert.equal(PERMISOS_DRAZO.length, 11)
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
