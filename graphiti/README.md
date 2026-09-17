# Graphiti MCP Server (FalkorDB + OpenAI)

Stack local de memoria para agentes: [Graphiti](https://help.getzep.com/graphiti) como MCP server sobre FalkorDB, en un solo contenedor (imagen oficial `zepai/knowledge-graph-mcp`).

## Setup

```bash
cp graphiti/.env.example graphiti/.env   # ya existe; editar OPENAI_API_KEY
```

## Uso

Desde la raíz del repo (`make help` lista todo):

```bash
make graphiti-up        # levantar
make graphiti-logs      # ver logs
make graphiti-status    # estado
make graphiti-health    # curl /health
make graphiti-down      # bajar, conserva el grafo
make graphiti-clean     # bajar y borrar el grafo (pide confirmación)
make graphiti-pull      # actualizar imagen (cambiar GRAPHITI_IMAGE_TAG en .env)
```

Equivalente directo: `cd graphiti && docker compose up -d` / `docker compose down`.

Verificar:

```bash
curl http://localhost:8000/health
```

| Servicio | URL |
|---|---|
| MCP (HTTP) | http://localhost:8000/mcp/ |
| FalkorDB Browser | http://localhost:3000 |
| FalkorDB (redis) | localhost:6379 |

## Consultar lo guardado

```bash
make graphiti-search Q='FalkorDB'     # búsqueda semántica (nodos + hechos) vía MCP
make graphiti-graph                   # episodios, entidades, relaciones (Cypher)
make graphiti-cypher C='MATCH (n) RETURN count(n)'
make graphiti-test                    # inserta episodio de prueba
```

- UI visual: http://localhost:3000. Login: Manual Configuration, host `localhost`, port `6379`, usuario y password vacíos (sin auth salvo que pongas `FALKORDB_PASSWORD`). Requiere `ENCRYPTION_KEY` en `.env`. Grafo `main` (= `GRAPHITI_GROUP_ID`).
- `graphiti/mcp.sh` llama cualquier tool MCP por HTTP: `./graphiti/mcp.sh tools/list '{}'`.
- Modelo: `Episodic` (lo que metes) → `Entity` (extraído) unidos por `RELATES_TO` (hechos, con `valid_at` / `invalid_at`).

## Clientes MCP

Este repo solo levanta el servidor. La configuración de clientes es global, no del proyecto.

Endpoint: `http://localhost:8000/mcp`. Reglas de uso para el agente: [cursor_rules.md](cursor_rules.md).

### Cursor

`~/.cursor/mcp.json`:

```json
{ "mcpServers": { "graphiti-memory": { "url": "http://localhost:8000/mcp/" } } }
```

Reglas globales: skill personal en `~/.cursor/skills/graphiti-memory/SKILL.md` (frontmatter `name`/`description` + contenido de `cursor_rules.md`).

### Claude Code

```bash
claude mcp add --transport http --scope user graphiti-memory http://localhost:8000/mcp
```

Verificar: `claude mcp get graphiti-memory`. Reglas globales: `~/.claude/CLAUDE.md`.

### Codex CLI

```bash
codex mcp add graphiti-memory --url http://localhost:8000/mcp
```

Verificar: `codex mcp get graphiti-memory`. Reglas globales: `~/.codex/AGENTS.md`.

### Claude Desktop

Solo stdio por archivo, va con puente `mcp-remote`. En `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "graphiti-memory": {
      "command": "/opt/homebrew/bin/npx",
      "args": ["-y", "mcp-remote", "http://localhost:8000/mcp"],
      "env": { "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" }
    }
  }
}
```

Ruta absoluta y `PATH` porque las apps GUI no heredan el PATH del shell. Reiniciar la app (Cmd+Q).

### Antigravity

Global en `~/.gemini/config/mcp_config.json` (clave `serverUrl`, no `url`):

```json
{ "mcpServers": { "graphiti-memory": { "serverUrl": "http://localhost:8000/mcp" } } }
```

Ver en la UI: Additional Options (...) > MCP Servers. Si no conecta, usar el mismo bloque `npx mcp-remote` de Claude Desktop. Reglas globales: `~/.gemini/GEMINI.md`.

## Persistencia

La imagen oficial arranca redis daemonizado sin AOF y sin trap de SIGTERM: al bajar el contenedor se pierde el grafo. [start-services.sh](start-services.sh) se monta encima del de la imagen y activa AOF (`appendfsync everysec`), snapshot cada 60s y `SHUTDOWN SAVE` al bajar. Datos en el volumen `graphiti_falkordb_data`. `make graphiti-clean` lo borra.

## Config

Todo por env vars en `.env`. La imagen incluye `config-docker-falkordb-combined.yaml`, que lee `MODEL_NAME`, `EMBEDDER_MODEL`, `OPENAI_API_KEY`, `GRAPHITI_GROUP_ID`, etc. Embedder: `text-embedding-3-small` (1536 dims).

Referencia: https://github.com/getzep/graphiti/tree/main/mcp_server
