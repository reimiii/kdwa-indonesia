import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { Database } from "bun:sqlite";
import { readFileSync } from "node:fs";

const PROJECT_DIR = import.meta.dir.replace(/\/src\/commands$/, "");
const DDL_PATH = `${PROJECT_DIR}/db/dump/schema.sql`;
const DATA_PATH = `${PROJECT_DIR}/db/dump/data.sql`;
const DB_PATH = `${PROJECT_DIR}/db/regions.sqlite`;
const JSON_DIR = `${PROJECT_DIR}/data/json`;

const EXPECTED_TOTAL = 91599;
const EXPECTED_LEVELS: Record<number, number> = {
  1: 38,
  2: 416,
  3: 98,
  4: 7285,
  5: 8496,
  6: 75252,
  7: 14,
};

let testDb: Database;

beforeAll(() => {
  testDb = new Database(":memory:");
  const ddl = readFileSync(DDL_PATH, "utf-8");
  const data = readFileSync(DATA_PATH, "utf-8");
  testDb.exec(ddl);
  testDb.exec(data);
});

afterAll(() => {
  testDb.close();
});

describe("Schema & Data SQL", () => {
  test("DDL + data SQL loads into fresh in-memory DB", () => {
    const count = testDb.query("SELECT COUNT(*) AS cnt FROM regions").get() as {
      cnt: number;
    };
    expect(count.cnt).toBe(EXPECTED_TOTAL);
  });

  for (const [level, expected] of Object.entries(EXPECTED_LEVELS)) {
    test(`level ${level} has ${expected} rows`, () => {
      const row = testDb
        .query("SELECT COUNT(*) AS cnt FROM regions WHERE level = ?")
        .get(level) as { cnt: number };
      expect(row.cnt).toBe(expected);
    });
  }
});

describe("Referential Integrity", () => {
  test("no orphan parent_code references", () => {
    const row = testDb
      .query(
        "SELECT COUNT(*) AS cnt FROM regions r WHERE r.parent_code IS NOT NULL AND r.parent_code NOT IN (SELECT code FROM regions)",
      )
      .get() as { cnt: number };
    expect(row.cnt).toBe(0);
  });

  test("no foreign key violations", () => {
    testDb.exec("PRAGMA foreign_keys = ON");
    const errors = testDb.query("PRAGMA foreign_key_check").all();
    expect(errors.length).toBe(0);
  });
});

describe("Data Constraints", () => {
  test("all codes are unique", () => {
    const row = testDb
      .query("SELECT COUNT(*) - COUNT(DISTINCT code) AS cnt FROM regions")
      .get() as { cnt: number };
    expect(row.cnt).toBe(0);
  });

  test("no NULL in required fields (code, name, level)", () => {
    const row = testDb
      .query(
        "SELECT COUNT(*) AS cnt FROM regions WHERE code IS NULL OR name IS NULL OR level IS NULL",
      )
      .get() as { cnt: number };
    expect(row.cnt).toBe(0);
  });
});

describe("JSON Export Files", () => {
  const files: Record<string, number> = {
    "provinces.json": 38,
    "regencies.json": 416,
    "cities.json": 98,
    "districts.json": 7285,
    "villages.json": 83762,
  };

  for (const [filename, expectedCount] of Object.entries(files)) {
    test(`${filename} is valid JSON with ${expectedCount} records`, async () => {
      const file = Bun.file(`${JSON_DIR}/${filename}`);
      expect(await file.exists()).toBe(true);
      const data = await file.json();
      expect(data.length).toBe(expectedCount);
    });
  }
});

describe("Idempotency", () => {
  test("re-running data SQL does not duplicate rows", () => {
    const data = readFileSync(DATA_PATH, "utf-8");
    testDb.exec(data);
    const row = testDb.query("SELECT COUNT(*) AS cnt FROM regions").get() as {
      cnt: number;
    };
    expect(row.cnt).toBe(EXPECTED_TOTAL);
  });
});