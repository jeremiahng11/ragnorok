#!/bin/bash
#
# Docker entrypoint for rAthena.
#
# athena-start is not usable as a container CMD: it backgrounds every server
# and returns immediately, so the container exits. This runs all three in the
# foreground, forwards their output to container stdout, and exits if any one
# of them dies so Docker's restart policy can react.
#
set -uo pipefail

cd /opt/rathena

PIDS=()

shutdown() {
  echo "[entrypoint] shutting down"
  for pid in "${PIDS[@]}"; do
    kill -TERM "$pid" 2>/dev/null || true
  done
  wait
  exit 0
}
trap shutdown SIGTERM SIGINT

if [ ! -s conf/import/inter_conf.txt ]; then
  echo "[entrypoint] WARNING: conf/import/inter_conf.txt is empty or missing."
  echo "[entrypoint] The servers will use defaults and fail to reach the database."
  echo "[entrypoint] Run setup-conf.sh — see the README."
fi

echo "[entrypoint] starting login-server"
./login-server &
PIDS+=($!)
sleep 3

echo "[entrypoint] starting char-server"
./char-server &
PIDS+=($!)
sleep 3

echo "[entrypoint] starting map-server"
./map-server &
PIDS+=($!)

echo "[entrypoint] all servers started (pids: ${PIDS[*]})"

# Exit as soon as any one of them stops, so the container restarts rather than
# limping along with a dead map server.
wait -n
CODE=$?
echo "[entrypoint] a server exited (code $CODE) — stopping the rest"
for pid in "${PIDS[@]}"; do
  kill -TERM "$pid" 2>/dev/null || true
done
wait
exit "$CODE"
