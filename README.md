# kdwa-indonesia

**Kumpulan Data Wilayah Administratif Indonesia**

Indonesian administrative region data — provinces, regencies, cities, districts, urban villages, and villages — sourced from [cahyadsn/wilayah](https://github.com/cahyadsn/wilayah) and exported as SQLite, SQL, CSV, and JSON.

## Project Structure

```
kdwa-indonesia/
├── cli                          # CLI entry point
├── src/commands/
│   ├── update.ts                # Download raw data & rebuild database
│   ├── export.ts                # Export database to JSON files
│   └── test.ts                  # Validation test suite (bun:test)
├── scripts/
│   ├── import_raw.sh            # Download & import raw wilayah.sql
│   └── migrate_regions.sh       # Transform raw data into regions table
├── db/
│   ├── regions.sqlite           # Main SQLite database (gitignored)
│   └── dump/
│       ├── schema.sql           # DDL only (table + indexes)
│       └── data.sql             # INSERT statements (batched, idempotent)
├── data/
│   ├── raw/
│   │   ├── wilayah.sql          # Original source dump (gitignored)
│   │   ├── wilayah.cleaned.sql  # MySQL-cleaned version (gitignored)
│   │   └── raw_regions.db      # Raw import DB (gitignored)
│   └── json/
│       ├── provinces.json
│       ├── regencies.json
│       ├── cities.json
│       ├── districts.json
│       └── villages.json
├── examples/
│   └── usage.ts                 # Example: fetch JSON from GitHub
└── package.json
```

## Setup

```bash
bun install
```

## Commands

### Update data

Downloads raw data from upstream and rebuilds the SQLite database:

```bash
bun cli update
```

### Export to JSON

Exports the database into partitioned JSON files in `data/json/`:

```bash
bun cli export
```

### Run tests

```bash
bun test
```

## Data Levels

| Level | Code | Description |
|-------|------|-------------|
| 1 | `11` | Province (provinsi) |
| 2 | `11.01` | Regency (kabupaten) |
| 3 | `12.72` | City (kota) |
| 4 | `11.01.01` | District (kecamatan) |
| 5 | `12.71.20.1001` | Urban village (kelurahan) |
| 6 | `11.01.01.2001` | Village (desa) |
| 7 | `95.02.01.3001` | Indigenous village (desa adat) |

## Using the JSON Data

Each file in `data/json/` contains an array of objects with `id`, `code`, `name`, and `breadcrumb`:

```ts
const api = (level: number) =>
  `https://raw.githubusercontent.com/reimiii/kdwa-indonesia/refs/heads/main/data/json/${level}.json`;

async function getProvinces() {
  const res = await fetch(api(1));
  return res.json();
}
```

Run the example:

```bash
bun run examples/usage.ts
```

## Using the SQL Files

To recreate the database from SQL files:

```bash
sqlite3 regions.sqlite < db/dump/schema.sql
sqlite3 regions.sqlite < db/dump/data.sql
```

The `data.sql` file uses `ON CONFLICT(code) DO NOTHING`, so it's safe to re-run.

## Source

Data sourced from [cahyadsn/wilayah](https://github.com/cahyadsn/wilayah).