#!/bin/bash
#
# rAthena post-deploy configuration.
#
# Run INSIDE the rathena container:
#
#   sudo docker cp setup-conf.sh $(sudo docker ps -qf name=rathena-jdci):/tmp/
#   sudo docker exec -it $(sudo docker ps -qf name=rathena-jdci) bash /tmp/setup-conf.sh
#
# Writes to /opt/rathena/conf/import/ which is a Docker volume, so everything
# here survives redeploys. Safe to re-run.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# EDIT THESE
# ---------------------------------------------------------------------------

# Must match DB_PASSWORD in Coolify.
DB_PASSWORD="ragnarok_CHANGEME"

# Server name shown in the client's server list.
SERVER_NAME="MyRO"

# Address clients are told to connect to for char/map servers.
#   - Tailscale (current): reachable from any device on the tailnet, no port
#     forwarding, nothing exposed to the internet. Every player needs the
#     Tailscale client and access to this tailnet.
#   - LAN only:            192.168.0.2
#   - Over the internet:   public IP or DDNS hostname, plus port forwarding
#   - Browser client only: 127.0.0.1
PUBLIC_IP="100.86.111.65"

# Inter-server credentials. Replaces the public s1/p1 defaults.
INTER_USER="rosrv"
INTER_PASS="$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"

# Rates as percentages. 100 = 1x. Currently 25x exp / 10x drop.
BASE_EXP_RATE=2500
JOB_EXP_RATE=2500
DROP_RATE=1000

# ---------------------------------------------------------------------------

CONF=/opt/rathena/conf/import
TMPL=/opt/rathena/conf/import-tmpl

echo "=========================================="
echo "rAthena configuration"
echo "=========================================="

if [ ! -d "$TMPL" ]; then
  echo "FATAL: $TMPL not found. Are you inside the rathena container?" >&2
  exit 1
fi

mkdir -p "$CONF"

echo "--> checking database connectivity"
if command -v mariadb > /dev/null 2>&1; then
  MYSQL=mariadb
elif command -v mysql > /dev/null 2>&1; then
  MYSQL=mysql
else
  echo "FATAL: no mysql/mariadb client in this image." >&2
  exit 1
fi

if ! $MYSQL -h db -u ragnarok -p"${DB_PASSWORD}" ragnarok -e "SELECT 1;" > /dev/null 2>&1; then
  echo "FATAL: cannot connect to the database as user 'ragnarok'." >&2
  echo "       Check DB_PASSWORD matches what the db container was created with," >&2
  echo "       and that the db container is running." >&2
  exit 1
fi
echo "    connected"

# Do this BEFORE writing the conf files. If it fails we must not leave the
# configs pointing at credentials that do not exist in the database.
echo "--> updating inter-server account (was s1/p1)"
$MYSQL -h db -u ragnarok -p"${DB_PASSWORD}" ragnarok << EOF
UPDATE login
   SET userid    = '${INTER_USER}',
       user_pass = '${INTER_PASS}'
 WHERE account_id = 1;
EOF
echo "    account_id 1 updated"


# Seed any template files we are not going to write ourselves.
for f in "$TMPL"/*; do
  base="$(basename "$f")"
  [ -e "$CONF/$base" ] || cp "$f" "$CONF/$base"
done

echo "--> writing inter_conf.txt (database connection)"
cat > "$CONF/inter_conf.txt" << EOF
// Database connection. Host 'db' is the compose service name, resolved on the
// internal Docker network.

login_server_ip: db
login_server_port: 3306
login_server_id: ragnarok
login_server_pw: ${DB_PASSWORD}
login_server_db: ragnarok

ipban_db_ip: db
ipban_db_port: 3306
ipban_db_id: ragnarok
ipban_db_pw: ${DB_PASSWORD}
ipban_db_db: ragnarok

char_server_ip: db
char_server_port: 3306
char_server_id: ragnarok
char_server_pw: ${DB_PASSWORD}
char_server_db: ragnarok

map_server_ip: db
map_server_port: 3306
map_server_id: ragnarok
map_server_pw: ${DB_PASSWORD}
map_server_db: ragnarok

web_server_ip: db
web_server_port: 3306
web_server_id: ragnarok
web_server_pw: ${DB_PASSWORD}
web_server_db: ragnarok

log_db_ip: db
log_db_port: 3306
log_db_id: ragnarok
log_db_pw: ${DB_PASSWORD}
log_db_db: ragnarok_logs
EOF

echo "--> writing login_conf.txt"
cat > "$CONF/login_conf.txt" << EOF
// Set to yes temporarily to self-register with a name ending in _M or _F,
// then set it back to no.
new_account: no

// Minimum group id allowed to connect while the server is in maintenance.
// login_conf's own defaults are fine for everything else.
EOF

echo "--> writing char_conf.txt"
cat > "$CONF/char_conf.txt" << EOF
// Credentials the char server uses to authenticate to the login server.
// Must match the account in the SQL 'login' table (updated by this script).
userid: ${INTER_USER}
passwd: ${INTER_PASS}

server_name: ${SERVER_NAME}

// Login server is in this same container.
login_ip: 127.0.0.1

// Address handed to clients for the char server.
char_ip: ${PUBLIC_IP}
EOF

echo "--> writing map_conf.txt"
cat > "$CONF/map_conf.txt" << EOF
// Credentials the map server uses to authenticate to the char server.
userid: ${INTER_USER}
passwd: ${INTER_PASS}

// Char server is in this same container.
char_ip: 127.0.0.1

// Address handed to clients for the map server.
map_ip: ${PUBLIC_IP}
EOF

echo "--> writing battle_conf.txt (rates)"
cat > "$CONF/battle_conf.txt" << EOF
// Percentages. 100 = 1x.
base_exp_rate: ${BASE_EXP_RATE}
job_exp_rate: ${JOB_EXP_RATE}

item_rate_common: ${DROP_RATE}
item_rate_heal: ${DROP_RATE}
item_rate_use: ${DROP_RATE}
item_rate_equip: ${DROP_RATE}
item_rate_card: ${DROP_RATE}
EOF

echo
echo "=========================================="
echo "Done."
echo
echo "  Server name : ${SERVER_NAME}"
echo "  Client addr : ${PUBLIC_IP}"
echo "  Inter user  : ${INTER_USER}"
echo "  Inter pass  : ${INTER_PASS}"
echo
echo "Save the inter-server password somewhere. It is randomly generated"
echo "each run, and re-running this script changes it in both places."
echo
echo "Now restart the resource in Coolify, then check:"
echo "  docker logs \$(docker ps -qf name=rathena-jdci) 2>&1 | tail -30"
echo "=========================================="
