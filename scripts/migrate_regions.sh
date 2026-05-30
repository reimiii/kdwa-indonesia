#!/usr/bin/env bash
#
# migrate_regions.sh — Transform raw wilayah data into the normalized regions table
#
# Reads from the raw SQLite database (imported by import_raw.sh), classifies each
# region by level, builds hierarchical breadcrumbs, and exports the schema + data
# as portable SQL files.
#
# Usage: bash scripts/migrate_regions.sh
#
# Prerequisites: data/raw/raw_regions.db must exist (run import_raw.sh first)
#
# Output:
#   db/regions.sqlite      — Normalized SQLite database
#   db/dump/schema.sql     — DDL only (CREATE TABLE + indexes)
#   db/dump/data.sql       — Batched INSERT statements (idempotent)
#
set -euo pipefail

RAW_DIR="data/raw"
DB_DIR="db"
DUMP_DIR="db/dump"

RAW_DB="$RAW_DIR/raw_regions.db"
REGIONS_DB="$DB_DIR/regions.sqlite"
DDL_SQL="$DUMP_DIR/schema.sql"
DATA_SQL="$DUMP_DIR/data.sql"

log() { echo "=== $1"; }

check_raw_database() {
  log "[1/4] Checking raw database..."
  if [[ ! -f "$RAW_DB" ]]; then
    echo "Error: $RAW_DB not found. Run import_raw.sh first."
    exit 1
  fi
}

create_schema() {
  log "[2/4] Creating regions database and importing data..."
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
create index idx_regions_level on regions(level);
create index idx_regions_name on regions(name);
create index idx_regions_level_name on regions(level, name);
SQL

  sqlite3 "$REGIONS_DB" <<SQL
attach database '$RAW_DB' as raw;

insert into regions (code, name, level)
select kode, nama, 1
from raw.wilayah
where length(kode) = 2;

insert into regions (code, name, level, parent_code)
select
    kode,
    nama,
    case
        when substr(kode, 4, 2) between '71' and '99' then 3
        else 2
    end,
    substr(kode, 1, 2)
from raw.wilayah
where length(kode) = 5;

insert into regions (code, name, level, parent_code)
select kode, nama, 4, substr(kode, 1, 5)
from raw.wilayah
where length(kode) = 8;

insert into regions (code, name, level, parent_code)
select
    kode,
    nama,
    case
        when substr(kode, 10, 1) = '1' then 5
        when substr(kode, 10, 1) = '2' then 6
        when substr(kode, 10, 1) = '3' then 7
    end,
    substr(kode, 1, 8)
from raw.wilayah
where length(kode) = 13;

with recursive region_path(code, name, parent_code, breadcrumb) as (
    select code, name, parent_code, name as breadcrumb
    from regions
    where parent_code is null

    union all

    select r.code, r.name, r.parent_code, r.name || ', ' || rp.breadcrumb
    from regions r
    join region_path rp on r.parent_code = rp.code
)
update regions
set breadcrumb = (
    select breadcrumb from region_path where region_path.code = regions.code
);

detach database raw;
SQL
}

export_schema() {
  log "[3/4] Exporting schema.sql..."
  mkdir -p "$DUMP_DIR"

  sqlite3 "$REGIONS_DB" <<SQL
.headers off
.mode list
.output $DDL_SQL

select 'PRAGMA foreign_keys = OFF;';

select 'drop trigger if exists ' || name || ';'
from sqlite_master where type = 'trigger' and name not like 'sqlite_%'
union all
select 'drop index if exists ' || name || ';'
from sqlite_master where type = 'index' and name not like 'sqlite_%'
union all
select 'drop table if exists ' || name || ';'
from sqlite_master where type = 'table' and name not like 'sqlite_%'
union all
select sql || ';'
from sqlite_master where type = 'table' and name not like 'sqlite_%'
union all
select sql || ';'
from sqlite_master where type = 'index' and name not like 'sqlite_%'
union all
select sql || ';'
from sqlite_master where type = 'trigger' and name not like 'sqlite_%';

select 'PRAGMA foreign_keys = ON;';

.output stdout
SQL
}

export_data() {
  log "[4/4] Exporting data.sql..."

  sqlite3 "$REGIONS_DB" <<SQL
.headers off
.mode list
.output $DATA_SQL

select 'PRAGMA foreign_keys = OFF;';

with numbered as (
    select
        row_number() over (order by code) as rn,
        code, name, breadcrumb, level, parent_code
    from regions
),
grouped as (
    select
        ((rn - 1) / 1000) as batch_id,
        '(' ||
            quote(code) || ', ' ||
            quote(name) || ', ' ||
            quote(breadcrumb) || ', ' ||
            level || ', ' ||
            case when parent_code is null then 'null' else quote(parent_code) end
        || ')' as values_sql
    from numbered
)
select
    'insert into regions (code, name, breadcrumb, level, parent_code) values ' ||
    group_concat(values_sql, ', ') ||
    ' on conflict(code) do nothing;'
from grouped
group by batch_id;

select 'PRAGMA foreign_keys = ON;';

.output stdout
SQL
}

main() {
  check_raw_database
  create_schema
  export_schema
  export_data

  log "Done."
  echo "Output:"
  echo "  SQLite DB : $REGIONS_DB"
  echo "  Schema    : $DDL_SQL"
  echo "  Data SQL  : $DATA_SQL"
  echo ""
  echo "Verification:"
  sqlite3 "$REGIONS_DB" "SELECT level, COUNT(*) AS count FROM regions GROUP BY level;"
}

main