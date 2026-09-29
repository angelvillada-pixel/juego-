class_name LocalTransport
extends NetTransport
## Transporte local: simulación autoritativa en un solo proceso.
## Los mensajes se entregan inmediatamente vía señal (sin red).

func send(msg: Dictionary) -> void:
	emit_signal("message_received", msg)