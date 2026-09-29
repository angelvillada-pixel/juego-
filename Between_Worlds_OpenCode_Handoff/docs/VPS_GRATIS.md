# Between Worlds — VPS gratis 24/7 (P1-P2)

Objetivo: una sola instancia pequeña siempre encendida por 0 €/mes.
Opción recomendada: **Oracle Cloud Always Free** (es de los pocos tiers
gratis que NO duerme las máquinas; Render/Fly gratis sí duermen o cobran
egress: no sirven para 24/7).

## 1. Crear la máquina (una vez, ~15 min)

1. Cuenta en Oracle Cloud (pide tarjeta, no cobra en Always Free).
2. Create Instance con imagen **Ubuntu 24.04**, shape Always Free:
   `VM.Standard.E2.1.Micro` (1 vCPU, 1 GB) o `VM.Standard.A1.Flex`
   (hasta 4 vCPU ARM, 24 GB entre todas tus instancias).
3. Guarda la clave SSH privada (`.key`, `chmod 400`).
4. Anota la **IP pública**.

## 2. Red y DNS (una vez)

- En el Security List de la subnet: abrir **ingress 22 (SSH), 80 y 443
  desde 0.0.0.0/0**. El 26500 NO se abre: solo Caddy habla con el juego.
- En tu registrador DNS: registro `A` de `juego.tudominio.com` → IP pública.
- En la máquina: `sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT`
  (igual 443) si `iptables` filtra por defecto en Ubuntu Oracle.

## 3. Docker + despliegue (una vez, ~10 min)

```bash
ssh -i clave.key ubuntu@IP
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu  # re-login
git clone https://github.com/angelvillada-pixel/juego-.git bw && cd bw/Between_Worlds_OpenCode_Handoff/Between_Worlds_OpenCode_Handoff
cp deploy/.env.example deploy/.env  # DOMAIN=juego.tudominio.com EMAIL=tú@mail
docker compose -f deploy/docker-compose.yml --env-file deploy/.env up -d --build
sleep 30 && docker compose -f deploy/docker-compose.yml ps
curl -sI https://juego.tudominio.com | head -1  # HTTP/2 101 al hacer upgrade WS
```

## 4. Smoke test contra producción

Desde tu PC, con el juego exportado o en editor, únete a
`wss://juego.tudominio.com`. En local el equivalente ya verificado es
`tests/smoke_join.gd` (WELCOME con proto + SNAPSHOT con tu id).

## 5. Límites honestos del tier gratis

- **RAM**: 1 GB en E2 Micro es justo (Godot headless + Caddy caben; no
  pongas nada más). Si hay OOM, pasar a A1 Flex (más RAM gratis).
- **Egress**: ~10 TB/mes incluidos: de sobra para 10 jugadores a 20 kbps.
- **Tú eres el on-call**: sin SLA. El compose lleva `restart: unless-stopped`
  y healthcheck; revisa `docker logs` tras cada despliegue.
- **Backups**: el volumen `bw-data` (SQLite futuro, telemetría) se respalda
  en el Punto 5 (P3-P5); hasta entonces, copia manual con
  `docker run --rm -v bw-data:/d -v $PWD:/b ubuntu tar czf /b/bw-data.tgz /d`.

## 6. Coste si se acaba lo gratis

Un VPS de 2 GB (Hetzner/Contabo) cuesta ~4-5 €/mes con el mismo compose
sin cambios. El diseño de una sola instancia escala vertical hasta ahí.
