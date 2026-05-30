import { Database } from "bun:sqlite";
import { cwd, exit } from "node:process";
import { readdir, mkdir } from "node:fs/promises";

const table: string = "regions";

async function connection() {
  const path = `${cwd()}/db/regions.sqlite`;
  const file = Bun.file(path);
  const exist = await file.exists();
  if (!exist) exit(1);

  return new Database(path);
}

export default async function run() {
  console.log("Running export command...");

  const db = await connection();

  const provinces = db
    .query(`select id, code, name, breadcrumb from ${table} where level = 1`)
    .all();

  const regencies = db
    .query(`select id, code, name, breadcrumb from ${table} where level = 2`)
    .all();

  const cities = db
    .query(`select id, code, name, breadcrumb from ${table} where level = 3`)
    .all();

  const districts = db
    .query(`select id, code, name, breadcrumb from ${table} where level = 4`)
    .all();

  const villages = db
    .query(
      `select id, code, name, breadcrumb from ${table} where level in (5,6,7)`,
    )
    .all();

  const outputDir = `${cwd()}/data/json`;

  await mkdir(outputDir, { recursive: true });

  await Bun.write(`${outputDir}/provinces.json`, JSON.stringify(provinces));
  await Bun.write(`${outputDir}/regencies.json`, JSON.stringify(regencies));
  await Bun.write(`${outputDir}/cities.json`, JSON.stringify(cities));
  await Bun.write(`${outputDir}/districts.json`, JSON.stringify(districts));
  await Bun.write(`${outputDir}/villages.json`, JSON.stringify(villages));

  console.log(`Exported records to ${outputDir}`);

  const files = await readdir(outputDir);
  for (const f of files) console.log(`- ${f}`);
}