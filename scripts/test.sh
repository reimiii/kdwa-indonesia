#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

DDL="$PROJECT_DIR/db/dump/schema.sql"
DATA="$PROJECT_DIR/db/dump/data.sql"
ORIG_DB="$PROJECT_DIR/db/regions.sqlite"
JSON_DIR="$PROJECT_DIR/data/json"

EXPECTED_TOTAL=91599
EXPECTED_LEVELS="1|38 2|416 3|98 4|7285 5|8496 6|75252 7|14"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }

echo "=== kdwa-indonesia test suite ==="
echo ""

echo "[1/6] Checking required files exist..."
for f in "$DDL" "$DATA" "$ORIG_DB"; do
    if [[ -f "$f" ]]; then pass "$(basename $f) exists"; else fail "$(basename $f) missing"; fi
done

echo "[2/6] Validating DDL + data SQL loads into fresh database..."
TEST_DB=$(mktemp /tmp/test_regions_XXXXX.sqlite)
trap "rm -f $TEST_DB" EXIT

if sqlite3 "$TEST_DB" < "$DDL" && sqlite3 "$TEST_DB" < "$DATA"; then
    pass "DDL + data SQL loaded without error"
else
    fail "DDL + data SQL failed to load"
fi

echo "[3/6] Validating row counts..."
total=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM regions;")
if [[ "$total" == "$EXPECTED_TOTAL" ]]; then
    pass "total rows: $total"
else
    fail "expected $EXPECTED_TOTAL rows, got $total"
fi

for expected in $EXPECTED_LEVELS; do
    lvl="${expected%%|*}"
    cnt="${expected##*|}"
    actual=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM regions WHERE level = $lvl;")
    if [[ "$actual" == "$cnt" ]]; then
        pass "level $lvl: $actual rows"
    else
        fail "level $lvl: expected $cnt, got $actual"
    fi
done

echo "[4/6] Validating referential integrity..."
orphans=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM regions r WHERE r.parent_code IS NOT NULL AND r.parent_code NOT IN (SELECT code FROM regions);")
if [[ "$orphans" == "0" ]]; then
    pass "no orphan parent_code references"
else
    fail "found $orphans orphan parent_code references"
fi

fk_errors=$(sqlite3 "$TEST_DB" "PRAGMA foreign_key_check;" | wc -l)
if [[ "$fk_errors" == "0" ]]; then
    pass "no foreign key violations"
else
    fail "found $fk_errors foreign key violations"
fi

echo "[5/6] Validating unique code constraint..."
dupe=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) - COUNT(DISTINCT code) FROM regions;")
if [[ "$dupe" == "0" ]]; then
    pass "all codes unique"
else
    fail "found $dupe duplicate codes"
fi

echo "[6/6] Validating JSON exports..."
if [[ -d "$JSON_DIR" ]]; then
    for lvl_name in provinces regencies cities districts villages; do
        f="$JSON_DIR/${lvl_name}.json"
        if [[ -f "$f" ]]; then
            count=$(python3 -c "import json; print(len(json.load(open('$f'))))" 2>/dev/null)
            if [[ -n "$count" ]] && [[ "$count" -gt "0" ]]; then
                pass "$lvl_name.json: $count records"
            else
                fail "$lvl_name.json: invalid or empty"
            fi
        else
            fail "$lvl_name.json: missing"
        fi
    done
else
    fail "data/json/ directory missing"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ "$FAIL" -gt "0" ]]; then
    exit 1
fi