import { build } from "esbuild"
import { readFile, mkdir, writeFile } from "node:fs/promises"

const output = "public/integrations/rubusoo-chat-sync.user.js"
await mkdir("public/integrations", { recursive: true })
await build({
  entryPoints: ["integrations/chat-sync/src/userscript/entry.js"],
  bundle: true,
  format: "iife",
  target: ["chrome110", "firefox115"],
  write: false,
  minify: false,
  legalComments: "none"
}).then(async result => {
  const header = await readFile("integrations/chat-sync/userscript-header.js", "utf8")
  await writeFile(output, `${header}\n${result.outputFiles[0].text}`)
})
console.log(output)
