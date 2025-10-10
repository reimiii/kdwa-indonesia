#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="database"
RAW_DB="$DATA_DIR/raw/raw_regions.db"
REGIONS_DB="$DATA_DIR/regions.db"
REGIONS_SQL="$DATA_DIR/regions.sql"

echo "=== [1/5] Checking raw database..."
if [[ ! -f "$RAW_DB" ]]; then
  echo "Error: $RAW_DB not found. Run import_raw.sh first."
  exit 1
fi

echo "=== [2/5] Creating regions.db schema..."
rm -f "$REGIONS_DB"
sqlite3 "$REGIONS_DB" <<'SQL'
drop table if exists regions;
create table regions (
    id integer primary key autoincrement,
    code text not null unique,
    name text not null,
    level integer, -- 1 = province, 2 = regency and city, 3 = district, 4 = urban village and village
    type text, -- province, regency, city, district, urban village, village
    parent_code text,
    foreign key (parent_code) references regions(code)
);

create index idx_regions_parent_code on regions(parent_code);
create index idx_regions_name on regions(name);

SQL

echo "=== [3/5] Copying data from raw_regions..."

sqlite3 "$REGIONS_DB" <<SQL
attach database '$RAW_DB' as raw;

-- Province (length 2)
insert into regions (code, name, level)
select kode, nama, 1 from raw.wilayah where length(kode) = 2;

-- Regency (length 5)
insert into regions (code, name, level, parent_code)
select kode, nama, 2, substr(kode, 1, 2) from raw.wilayah where length(kode) = 5;

-- District (length 8)
insert into regions (code, name, level, parent_code)
select kode, nama, 3, substr(kode, 1, 5) from raw.wilayah where length(kode) = 8;

-- Village (length 13)
insert into regions (code, name, level, parent_code)
select kode, nama, 4, substr(kode, 1, 8) from raw.wilayah where length(kode) = 13;

-- Update type Province
update regions set type = 'province' where level = 1;

-- Update type District
update regions set type = 'district' where level = 3;

-- Update type Regency or City
update regions
    set type = case
        when substr(code, 4, 2) between '71' and '99' then 'city'
        else 'regency'
    end
where level = 2;

-- Update type Village or Urban Village
update regions
    set type = case
        when substr(code, 10, 1) = '1' then 'urban village'
        when substr(code, 10, 1) = '2' then 'village'
    end
where level = 4;

detach database raw;
SQL

echo "=== [4/5] Exporting regions.sql..."
sqlite3 "$REGIONS_DB" .dump > "$REGIONS_SQL"

grep CREATE "$REGIONS_SQL"

echo "=== [5/5] Verification summary:"
sqlite3 "$REGIONS_DB" "SELECT level, COUNT(*) AS count FROM regions GROUP BY level;"

echo "=== Done."
echo "Output:"
echo "  SQLite DB : $REGIONS_DB"
echo "  SQL Export: $REGIONS_SQL"
