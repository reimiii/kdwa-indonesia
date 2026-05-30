import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { Database } from "bun:sqlite";

const PROJECT_DIR = import.meta.dir.replace(/\/src\/commands$/, "");

const SCHEMA_PATH = `${PROJECT_DIR}/db/dump/schema.sql`;
const DATA_PATH = `${PROJECT_DIR}/db/dump/data.sql`;
const JSON_DIR = `${PROJECT_DIR}/data/json`;

const EXPECTED_TOTAL = 91599;

const EXPECTED_BY_LEVEL: Record<number, number> = {
  1: 38,
  2: 416,
  3: 98,
  4: 7285,
  5: 8496,
  6: 75252,
  7: 14,
};

const EXPECTED_BY_FILE: Record<string, number> = {
  "provinces.json": 38,
  "regencies.json": 416,
  "cities.json": 98,
  "districts.json": 7285,
  "villages.json": 83762,
};

let db: Database;
let stmtCountByLevel: ReturnType<Database["prepare"]>;

beforeAll(async () => {
  db = new Database(":memory:");
  db.run(await Bun.file(SCHEMA_PATH).text());
  db.run(await Bun.file(DATA_PATH).text());
  stmtCountByLevel = db.prepare("SELECT COUNT(*) AS cnt FROM regions WHERE level = ?");
});

afterAll(() => db.close());

function count(sql: string) {
  return (db.query(sql).get() as { cnt: number }).cnt;
}

describe("Schema & Data SQL", () => {
  test(`total rows = ${EXPECTED_TOTAL}`, () => {
    expect(count("SELECT COUNT(*) AS cnt FROM regions")).toBe(EXPECTED_TOTAL);
  });

  test.each(Object.entries(EXPECTED_BY_LEVEL))("level %s = %i rows", (level, expected) => {
    expect((stmtCountByLevel.get(level) as { cnt: number }).cnt).toBe(expected);
  });
});

describe("Referential Integrity", () => {
  test("no orphan parent_code references", () => {
    expect(count("SELECT COUNT(*) AS cnt FROM regions WHERE parent_code IS NOT NULL AND parent_code NOT IN (SELECT code FROM regions)")).toBe(0);
  });

  test("no foreign key violations", () => {
    db.run("PRAGMA foreign_keys = ON");
    expect(db.query("PRAGMA foreign_key_check").all().length).toBe(0);
  });
});

describe("Data Constraints", () => {
  test("all codes are unique", () => {
    expect(count("SELECT COUNT(*) - COUNT(DISTINCT code) AS cnt FROM regions")).toBe(0);
  });

  test("no NULL values in code, name, or level", () => {
    expect(count("SELECT COUNT(*) AS cnt FROM regions WHERE code IS NULL OR name IS NULL OR level IS NULL")).toBe(0);
  });
});

describe("JSON Export Files", () => {
  test.each(Object.entries(EXPECTED_BY_FILE))("%s has %i records", async (filename, expected) => {
    const file = Bun.file(`${JSON_DIR}/${filename}`);
    expect(await file.exists()).toBe(true);
    expect((await file.json()).length).toBe(expected);
  });
});

describe("Idempotency", () => {
  test("re-running data SQL does not duplicate rows", async () => {
    db.run(await Bun.file(DATA_PATH).text());
    expect(count("SELECT COUNT(*) AS cnt FROM regions")).toBe(EXPECTED_TOTAL);
  });
});