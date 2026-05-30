import { rmSync } from "node:fs";
import { cwd } from "node:process";

const PATHS = [
  "data/raw",
  "data/json",
  "data/regions.csv",
  "db/regions.sqlite",
  "db/dump/schema.sql",
  "db/dump/data.sql",
  "db/dump/regions.sql",
];

export default async function run() {
  console.log("Removing generated files...\n");

  let removed = 0;
  for (const relPath of PATHS) {
    const absPath = `${cwd()}/${relPath}`;
    try {
      rmSync(absPath, { recursive: true, force: true });
      console.log(`  removed ${relPath}`);
      removed++;
    } catch (err: any) {
      if (err.code !== "ENOENT") {
        console.error(`  failed ${relPath}: ${err.message}`);
      } else {
        console.log(`  skipped ${relPath} (not found)`);
      }
    }
  }

  console.log(`\nDone. ${removed} paths cleaned.`);
}