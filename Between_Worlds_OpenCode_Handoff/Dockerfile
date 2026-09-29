# Servidor dedicado de Between Worlds (Godot 4.7.2 headless).
# Uso: docker build -t between-worlds-server . && docker run -p 26500:26500 between-worlds-server
# Ver docs/DEPLOY.md.

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
CMD ["--port=26500", "--mode=frontline", "--map=lab"]
