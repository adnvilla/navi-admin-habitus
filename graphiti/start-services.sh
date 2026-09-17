#!/bin/bash
# Reemplaza /start-services.sh de la imagen zepai/knowledge-graph-mcp.
# Diferencias con el original:
#   - FalkorDB con AOF + snapshot frecuente (el original no persiste nada
#     salvo que se cumpla "save 3600 1 / 300 100 / 60 10000").
#   - Trap de SIGTERM: apaga el MCP server y hace SHUTDOWN SAVE en FalkorDB.
#     El original hace `exec uv run`, redis muere sin guardar al bajar.
#   - Aplica FALKORDB_PASSWORD a redis (--requirepass). El original lo ignora.
set -e

# Password opcional: si FALKORDB_PASSWORD viene vacío, redis corre sin auth.
REDIS_AUTH_ARGS=()
CLI_AUTH_ARGS=()
if [ -n "${FALKORDB_PASSWORD:-}" ]; then
  REDIS_AUTH_ARGS=(--requirepass "$FALKORDB_PASSWORD")
  CLI_AUTH_ARGS=(-a "$FALKORDB_PASSWORD" --no-auth-warning)
fi
rcli() { redis-cli -h localhost -p 6379 "${CLI_AUTH_ARGS[@]}" "$@"; }

echo "Starting FalkorDB..."
redis-server \
  --loadmodule /var/lib/falkordb/bin/falkordb.so \
  --protected-mode no \
  --bind 0.0.0.0 \
  --port 6379 \
  --dir /var/lib/falkordb/data \
  --appendonly yes \
  --appendfsync everysec \
  --save "60 1" \
  "${REDIS_AUTH_ARGS[@]}" \
  --daemonize yes

echo "Waiting for FalkorDB to be ready..."
until rcli ping > /dev/null 2>&1; do sleep 1; done
echo "FalkorDB is ready!"

if [ "${BROWSER:-1}" = "1" ]; then
  if [ -f /var/lib/falkordb/browser/server.js ]; then
    echo "Starting FalkorDB Browser on port 3000..."
    (cd /var/lib/falkordb/browser && HOSTNAME="0.0.0.0" node server.js > /var/log/graphiti/browser.log 2>&1 &)
  else
    echo "Warning: FalkorDB Browser files not found, skipping"
  fi
else
  echo "FalkorDB Browser disabled (BROWSER=${BROWSER})"
fi

shutdown() {
  echo "SIGTERM: stopping MCP server..."
  kill -TERM "$MCP_PID" 2>/dev/null || true
  wait "$MCP_PID" 2>/dev/null || true
  echo "Saving FalkorDB and shutting down..."
  rcli SHUTDOWN SAVE || true
  exit 0
}
trap shutdown TERM INT

echo "Starting MCP server..."
cd /app/mcp
/root/.local/bin/uv run --no-sync main.py &
MCP_PID=$!
wait "$MCP_PID"
