// La versión del plugin y la que viaja en la cabecera X-Drazo-Plugin tienen que ser la misma (se cambian a mano en dos sitios).
// Uso: node --test tests/version.test.mjs
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { test } from "node:test"
import { fileURLToPath } from "node:url"

const plugin = join(dirname(fileURLToPath(import.meta.url)), "..", "plugins", "drazo")
const json = (ruta) => JSON.parse(readFileSync(join(plugin, ruta), "utf8"))

test("la versión de plugin.json es la de la cabecera X-Drazo-Plugin de .mcp.json", () => {
  const version = json(".claude-plugin/plugin.json").version
  assert.match(version, /^\d+\.\d+\.\d+$/)
  assert.equal(json(".mcp.json").mcpServers.drazo.headers["X-Drazo-Plugin"], version)
})

test("la versión es la 0.7.0 o posterior (las cuentas con varias marcas)", () => {
  const [a, b] = json(".claude-plugin/plugin.json").version.split(".").map(Number)
  assert.ok(a > 0 || b >= 7)
})

test("el plugin pide la instalación en userConfig (opcional) y la manda en su cabecera", () => {
  const campo = json(".claude-plugin/plugin.json").userConfig.instalacion
  assert.equal(campo.type, "string")
  assert.notEqual(campo.required, true)
  assert.equal(json(".mcp.json").mcpServers.drazo.headers["X-Drazo-Instalacion"], "${user_config.instalacion}")
  assert.match(json(".claude-plugin/plugin.json").userConfig.licencia.description, /drzc_/)
})
