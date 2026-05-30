import { Database } from "bun:sqlite";
import { mkdir } from "node:fs/promises";
import { cwd, exit } from "node:process";

const DB_PATH = `${cwd()}/db/regions.sqlite`;
const OUTPUT_DIR = `${cwd()}/data/json`;

const LEVEL_QUERIES: Record<string, string> = {
  provinces: "select id, code, name, breadcrumb from regions where level = 1",
  regencies: "select id, code, name, breadcrumb from regions where level = 2",
  cities: "select id, code, name, breadcrumb from regions where level = 3",
  districts: "select id, code, name, breadcrumb from regions where level = 4",
  villages:
    "select id, code, name, breadcrumb from regions where level in (5, 6, 7)",
};

async function openDatabase(): Promise<Database> {
  const file = Bun.file(DB_PATH);
  if (!(await file.exists())) {
    console.error(`Database not found: ${DB_PATH}`);
    console.error("Run 'bun cli update' first.");
    exit(1);
  }
  return new Database(DB_PATH);
}

export default async function run() {
  console.log("Running export command...");

  const db = await openDatabase();
  await mkdir(OUTPUT_DIR, { recursive: true });

  for (const [name, query] of Object.entries(LEVEL_QUERIES)) {
    const rows = db.query(query).all();
    await Bun.write(`${OUTPUT_DIR}/${name}.json`, JSON.stringify(rows));
    console.log(`  ${name}: ${rows.length} records`);
  }

  db.close();
  console.log(`Exported to ${OUTPUT_DIR}`);
}