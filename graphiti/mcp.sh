#!/bin/bash
# Llama al MCP server por HTTP (streamable). Uso:
#   ./mcp.sh tools/list '{}'
#   ./mcp.sh tools/call '{"name":"search_nodes","arguments":{"query":"..."}}'
# Var MCP_PORT opcional (default 8000).
URL=http://localhost:${MCP_PORT:-8000}/mcp
H=(-H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream')
SID=$(curl -s -i -X POST $URL "${H[@]}" -d '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"curl","version":"0"}}}' | grep -i mcp-session-id | awk '{print $2}' | tr -d '\r')
curl -s -X POST $URL "${H[@]}" -H "mcp-session-id: $SID" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null
curl -s -X POST $URL "${H[@]}" -H "mcp-session-id: $SID" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":$2}" | sed -n 's/^data: //p'
