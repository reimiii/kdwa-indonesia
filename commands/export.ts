import { Database } from "bun:sqlite";
import { cwd, exit } from "node:process";
import { readdir } from "node:fs/promises";
import { mkdir } from "node:fs/promises";

const table: string = "regions";

async function connection() {
  const path = `${cwd()}/database/regions.db`;
  const file = Bun.file(path);
  const exsist = await file.exists();
  if (!exsist) exit(1);

  return new Database(path);
}

export default async function run() {
  console.log("🚀 Running export command...");

  const db = await connection();

  const provinces = db.query(`select * from ${table} where level = 1`).all();
  const regenciesOrCities = db
    .query(`select * from ${table} where level = 2`)
    .all();

  const districts = db.query(`select * from ${table} where level = 3`).all();
  const urbanOrVillages = db
    .query(`select * from ${table} where level = 4`)
    .all();

  const outputDir = `${cwd()}/json`;

  await Bun.write(`${outputDir}/1.json`, JSON.stringify(provinces));
  await Bun.write(`${outputDir}/2.json`, JSON.stringify(regenciesOrCities));
  await Bun.write(`${outputDir}/3.json`, JSON.stringify(districts));
  await Bun.write(`${outputDir}/4.json`, JSON.stringify(urbanOrVillages));

  console.log(`✅ Exported records to ${outputDir}`);
  const files = await readdir(outputDir);
  for (const f of files) console.log(`  - ${f}`);
}
