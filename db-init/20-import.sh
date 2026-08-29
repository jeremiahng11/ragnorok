#!/bin/bash
set -euo pipefail

M=(mariadb -uroot -p"${MARIADB_ROOT_PASSWORD}")

echo "==> importing main.sql into ragnarok"
"${M[@]}" ragnarok < /sql/main.sql

echo "==> importing web.sql into ragnarok"
"${M[@]}" ragnarok < /sql/web.sql

echo "==> importing logs.sql into ragnarok_logs"
"${M[@]}" ragnarok_logs < /sql/logs.sql

# Optional extras — uncomment if you want them.
# "${M[@]}" ragnarok < /sql/item_db2.sql
# "${M[@]}" ragnarok < /sql/mob_db2.sql

echo "==> rAthena schema import complete"
