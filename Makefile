# Graphiti MCP Server (FalkorDB + OpenAI) — ver graphiti/README.md

COMPOSE := docker compose -f graphiti/docker-compose.yml --env-file graphiti/.env

# Valores de graphiti/.env que usan los comandos del lado host.
envval = $(or $(shell grep -s '^$(1)=' graphiti/.env | tail -1 | cut -d= -f2-),$(2))
export MCP_PORT := $(call envval,MCP_PORT,8000)
# En FalkorDB, Graphiti guarda cada group_id en un grafo con ese nombre
# (no en FALKORDB_DATABASE). Por eso GRAPH.QUERY apunta al group_id.
GROUP ?= $(call envval,GRAPHITI_GROUP_ID,main)
# Q y C llegan a las recetas por entorno, nunca interpolados en el shell.
export Q C

.PHONY: help graphiti-up graphiti-down graphiti-restart graphiti-logs graphiti-status graphiti-health graphiti-pull graphiti-clean graphiti-test graphiti-search graphiti-graph graphiti-cypher

help:
	@echo "graphiti-up       levantar (detached)"
	@echo "graphiti-down     bajar, conserva el grafo"
	@echo "graphiti-restart  reiniciar"
	@echo "graphiti-logs     logs en vivo"
	@echo "graphiti-status   estado del contenedor"
	@echo "graphiti-health   curl al /health"
	@echo "graphiti-pull     actualizar imagen"
	@echo "graphiti-clean    bajar y BORRAR el grafo (volúmenes)"
	@echo "graphiti-test     add_memory de prueba + búsqueda (gasta tokens OpenAI)"
	@echo "graphiti-search   Q='texto'  buscar nodos y hechos"
	@echo "graphiti-graph    resumen del grafo: episodios, entidades, relaciones"
	@echo "graphiti-cypher   C='MATCH ...'  Cypher crudo contra FalkorDB"

graphiti/.env:
	cp graphiti/.env.example graphiti/.env
	@echo ">> Edita graphiti/.env y pon OPENAI_API_KEY"

graphiti-up: graphiti/.env
	$(COMPOSE) up -d

graphiti-down:
	$(COMPOSE) down

graphiti-restart:
	$(COMPOSE) restart

graphiti-logs:
	$(COMPOSE) logs -f

graphiti-status:
	$(COMPOSE) ps

graphiti-health:
	curl -s http://localhost:$(MCP_PORT)/health; echo

graphiti-pull:
	$(COMPOSE) pull

graphiti-clean:
	@read -p "Borra el grafo completo. Continuar? [y/N] " r; [ "$$r" = "y" ] || exit 1
	$(COMPOSE) down -v

MCP   := ./graphiti/mcp.sh
JSON  := python3 -c "import sys,json; print(json.load(sys.stdin)['result']['content'][0]['text'])"
# redis-cli dentro del contenedor, con auth solo si FALKORDB_PASSWORD está puesto.
REDIS := docker exec graphiti-falkordb sh -c 'exec redis-cli $${FALKORDB_PASSWORD:+-a "$$FALKORDB_PASSWORD" --no-auth-warning} "$$@"' --

graphiti-test:
	$(MCP) tools/call '{"name":"add_memory","arguments":{"name":"prueba","episode_body":"Adan trabaja en el proyecto navi-admin-habitus. Adan prefiere usar FalkorDB como base de datos de grafos para Graphiti. El proyecto navi-admin-habitus se levanta con docker compose y un Makefile.","source":"text","source_description":"make graphiti-test"}}' | $(JSON)
	@echo ">> encolado; espera ~20s y corre: make graphiti-search Q='FalkorDB'"

graphiti-search:
	@echo "== nodos =="; $(MCP) search search_nodes max_nodes | $(JSON)
	@echo "== hechos =="; $(MCP) search search_memory_facts max_facts | $(JSON)

graphiti-graph:
	@echo "== episodios =="; $(REDIS) GRAPH.QUERY "$(GROUP)" "MATCH (e:Episodic) RETURN e.name, e.source_description, e.created_at ORDER BY e.created_at DESC LIMIT 20"
	@echo "== entidades =="; $(REDIS) GRAPH.QUERY "$(GROUP)" "MATCH (n:Entity) RETURN n.name, n.summary ORDER BY n.created_at DESC LIMIT 30"
	@echo "== relaciones =="; $(REDIS) GRAPH.QUERY "$(GROUP)" "MATCH (a:Entity)-[r:RELATES_TO]->(b:Entity) WHERE r.expired_at IS NULL RETURN a.name, r.name, b.name, r.fact LIMIT 50"

graphiti-cypher:
	@$(REDIS) GRAPH.QUERY "$(GROUP)" "$$C"
