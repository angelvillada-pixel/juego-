# Servidor dedicado de Between Worlds (Godot 4.7.2 headless).
# Uso directo (solo LAN/dev): docker build -t between-worlds-server . && docker run -p 127.0.0.1:26500:26500 between-worlds-server
# Producción (wss:// obligatorio): docker compose -f deploy/docker-compose.yml --env-file deploy/.env up -d --build
# Ver docs/DEPLOY.md. El 26500 NUNCA se publica a internet sin Caddy delante.

FROM ubuntu:24.04 AS fetch
ARG GODOT_VERSION=4.7.2
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates unzip wget \
	&& rm -rf /var/lib/apt/lists/*
RUN wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip -O /tmp/godot.zip \
	&& unzip -q /tmp/godot.zip -d /opt \
	&& mv /opt/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /opt/godot \
	&& chmod +x /opt/godot \
	&& rm /tmp/godot.zip

FROM ubuntu:24.04
RUN useradd -m bw && mkdir -p /game && chown bw:bw /game
COPY --from=fetch /opt/godot /usr/local/bin/godot
COPY . /game
WORKDIR /game
USER bw
EXPOSE 26500
ENTRYPOINT ["godot", "--headless", "--path", "/game", "-s", "res://src/server/server_main.gd", "--"]
# S2: dentro de compose Caddy alcanza al juego por la red del compose, así que
# el bind es 0.0.0.0 del contenedor; el compose solo publica 127.0.0.1:26500.
CMD ["--port=26500", "--bind=0.0.0.0", "--mode=frontline", "--map=lab"]
