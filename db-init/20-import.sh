#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "rAthena schema import starting"
echo "=========================================="

if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
  echo "FATAL: MARIADB_ROOT_PASSWORD is empty. Check DB_ROOT_PASSWORD in Coolify." >&2
  exit 1
fi

M=(mariadb -uroot -p"${MARIADB_ROOT_PASSWORD}")

import() {
  local file="$1" db="$2"
  if [ ! -f "/sql/${file}" ]; then
    echo "FATAL: /sql/${file} not found" >&2
    exit 1
  fi
  echo "--> importing ${file} into ${db}"
  "${M[@]}" "${db}" < "/sql/${file}"
}

import main.sql ragnarok
import web.sql  ragnarok
import logs.sql ragnarok_logs

# Optional extras -- uncomment if you want them.
# import item_db2.sql ragnarok
# import mob_db2.sql  ragnarok

echo "--> verifying"
"${M[@]}" -N -e \
  "SELECT CONCAT('ragnarok tables: ', COUNT(*)) FROM information_schema.tables WHERE table_schema='ragnarok';
   SELECT CONCAT('ragnarok_logs tables: ', COUNT(*)) FROM information_schema.tables WHERE table_schema='ragnarok_logs';"

echo "=========================================="
echo "rAthena schema import complete"
echo "=========================================="
