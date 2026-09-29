# Between Worlds — Plan de benchmarks de red (Punto 3)

Estado: protocolo seq/ack + `SimTransport` listos para laboratorio. La medición
de campo (2 máquinas / navegadores) queda pendiente: requiere Godot 4.7.2 con
export web + un servidor dedicado accesible.

## Escenarios de laboratorio (ejecutables hoy con `SimTransport`)

| Retardo | Pérdida | Qué validar |
|---|---|---|
| 0 ms | 0% | Paridad con loopback (base) |
| 50 ms | 0% | Interpolación remota suave, RTT ≈ 100ms estimado |
| 100 ms | 0% | Snap solo si deriva > 96px; hits dentro de tolerancia rewind |
| 50 ms | 1% | ACK poda buffer; ack_rate ≈ 99% |
| 100 ms | 2% | Sin kicks falsos (rate-limit con margen); cheat_log sin `speed` |

Comando (cuando haya binario Godot):

```
godot --headless --path . -s res://tests/run_tests.gd
```

## Campo (pendiente)

1. Servidor dedicado en LAN (`--port`), 2 clientes PC: medir RTT real y
   registrar `cheat_log` (debe estar vacío en juego limpio).
2. Mismo test contra build web (WebSocket): comparar jitter/ACK rate.
3. Decidir WebSocket vs WebRTC/DataChannel con datos, no por intuición.
   Solo entonces cerrar OPEN_QUESTIONS 7 como definitiva.

## Presupuesto (prototipo)

- Snapshot 30 Hz solo a sesiones de red; eventos raros por mensaje.
- Objetivo: ≤ 20 kbps por jugador (pendiente de medición).
