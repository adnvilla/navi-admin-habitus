#!/bin/bash
# Llama al MCP server por HTTP (streamable). Uso:
#   ./mcp.sh tools/list '{}'
#   ./mcp.sh tools/call '{"name":"search_nodes","arguments":{"query":"..."}}'
#   Q='texto libre' ./mcp.sh search search_nodes max_nodes
#     (arma el JSON con json.dumps; la query va por entorno, nunca por el shell)
# Var MCP_PORT opcional (default 8000).
if [ "$1" = "search" ]; then
  PARAMS=$(python3 -c 'import json,os,sys; print(json.dumps({"name":sys.argv[1],"arguments":{"query":os.environ.get("Q",""),sys.argv[2]:5}}))' "$2" "$3")
  set -- tools/call "$PARAMS"
fi
URL=http://localhost:${MCP_PORT:-8000}/mcp
H=(-H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream')
SID=$(curl -s -i -X POST $URL "${H[@]}" -d '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"curl","version":"0"}}}' | grep -i mcp-session-id | awk '{print $2}' | tr -d '\r')
curl -s -X POST $URL "${H[@]}" -H "mcp-session-id: $SID" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null
curl -s -X POST $URL "${H[@]}" -H "mcp-session-id: $SID" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":$2}" | sed -n 's/^data: //p'
