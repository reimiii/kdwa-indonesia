#!/usr/bin/env bun
import { run as clean } from "./src/commands/clean";
import { run as update } from "./src/commands/update";
import { run as exportCmd } from "./src/commands/export";

type Command = () => Promise<void>;

const COMMANDS: Record<string, Command> = { clean, update, export: exportCmd };
const [command] = Bun.argv.slice(2);

function printHelp(): never {
  console.log("Usage: bun cli <command>");
  console.log("Commands:");
  for (const c of Object.keys(COMMANDS)) console.log(`  ${c}`);
  console.log("  test  (run with: bun test)");
  process.exit(command === undefined ? 0 : 1);
}

if (!command || !(command in COMMANDS)) {
  printHelp();
}

await COMMANDS[command]!();