#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="database"
RAW_DB="$DATA_DIR/raw/raw_regions.db"
REGIONS_DB="$DATA_DIR/regions.sqlite"
REGIONS_SQL="$DATA_DIR/regions.sql"
REGIONS_CSV="$DATA_DIR/regions.csv"

echo "=== [1/6] Checking raw database..."
if [[ ! -f "$RAW_DB" ]]; then
  echo "Error: $RAW_DB not found. Run import_raw.sh first."
  exit 1
fi

echo "=== [2/6] Creating regions.db schema..."
rm -f "$REGIONS_DB"
sqlite3 "$REGIONS_DB" <<'SQL'
drop table if exists regions;
create table regions (
    id integer primary key autoincrement,
    code text not null unique,
    name text not null,
    breadcrumb text,
    level integer not null,
        -- 1 = province,
        -- 2 = regency,
        -- 3 = city,
        -- 4 = district,
        -- 5 = urban village,
        -- 6 = village,
        -- 7 = indigenous village
    parent_code text,
    foreign key (parent_code) references regions(code)
);

create index idx_regions_parent_code on regions(parent_code);
create index idx_regions_name on regions(name);

SQL

echo "=== [3/6] Copying data from raw_regions..."

sqlite3 "$REGIONS_DB" <<SQL
attach database '$RAW_DB' as raw;

-- Province (2 digit)
insert into regions (code, name, level)
select kode, nama, 1
from raw.wilayah
where length(kode) = 2;

-- Regency / City (5 digit)
insert into regions (code, name, level, parent_code)
select
    kode,
    nama,
    case
        when substr(kode, 4, 2) between '71' and '99' then 3 -- city
        else 2 -- regency
    end,
    substr(kode, 1, 2)
from raw.wilayah
where length(kode) = 5;

-- District (8 digit)
insert into regions (code, name, level, parent_code)
select
    kode,
    nama,
    4,
    substr(kode, 1, 5)
from raw.wilayah
where length(kode) = 8;

-- Urban Village / Village (13 digit)
insert into regions (code, name, level, parent_code)
select
    kode,
    nama,
    case
        when substr(kode, 10, 1) = '1' then 5 -- urban village
        when substr(kode, 10, 1) = '2' then 6 -- village
        when substr(kode, 10, 1) = '3' then 7 -- indigenous village
    end,
    substr(kode, 1, 8)
from raw.wilayah
where length(kode) = 13;

-- Build reversed breadcrumb (child → parent)
with recursive region_path(code, name, parent_code, breadcrumb) as (
    select
        code,
        name,
        parent_code,
        name as breadcrumb
    from regions
    where parent_code is null

    union all

    select
        r.code,
        r.name,
        r.parent_code,
        r.name || ', ' || rp.breadcrumb
    from regions r
    join region_path rp on r.parent_code = rp.code
)

update regions
set breadcrumb = (
    select breadcrumb
    from region_path
    where region_path.code = regions.code
);

detach database raw;
SQL

echo "=== [4/6] Exporting regions.sql..."
sqlite3 "$REGIONS_DB" .dump > "$REGIONS_SQL"

grep CREATE "$REGIONS_SQL"

echo "=== [5/6] Exporting regions.csv..."
sqlite3 "$REGIONS_DB" <<SQL
.headers on
.mode csv
.output $REGIONS_CSV
select * from regions;
.output stdout
SQL

echo "=== [6/6] Verification summary:"
sqlite3 "$REGIONS_DB" "SELECT level, COUNT(*) AS count FROM regions GROUP BY level;"

echo "=== Done."
echo "Output:"
echo "  SQLite DB : $REGIONS_DB"
echo "  SQL Export: $REGIONS_SQL"
