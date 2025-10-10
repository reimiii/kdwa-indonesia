#!/usr/bin/env bun
import { readdir } from "node:fs/promises";

const [command, ..._args] = Bun.argv.slice(2);

async function listCommands() {
  const dir = `${import.meta.dir}/commands`;
  const result: string[] = [];

  try {
    const files = await readdir(dir);
    for await (const file of files) {
      if (file.endsWith(".ts")) {
        result.push(file.replace(".ts", ""));
      }
    }
  } catch (_) {}

  return result;
}

async function main() {
  const commands = await listCommands();

  if (!command) {
    console.log("🧭 Usage: bun geo <command>");
    console.log("Available commands:");
    for (const c of commands) console.log(`  • ${c}`);
    return;
  }

  if (!commands.includes(command)) {
    console.log(`❌ Unknown command: ${command}`);
    console.log("Available commands:");
    for (const c of commands) console.log(`  • ${c}`);
    return;
  }

  const mod = await import(`./commands/${command}.ts`);
  await mod.default();
}

await main();
