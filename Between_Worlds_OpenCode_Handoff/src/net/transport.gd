class_name NetTransport
extends RefCounted
## Interfaz abstracta de transporte (stub para el vertical slice).
## La arquitectura mantendrá aquí WebSocket y WebRTC/DataChannel cuando llegue
## la etapa de networking real (Etapas 2-4 del Prototype Blueprint).

signal message_received(msg: Dictionary)

# Señales de ciclo de vida (LocalTransport las emite de forma inmediata/no-op).
signal connected
signal disconnected


# Base autoritativa: esta capa aceptará validación de daño, construcción y objetivos cuando se conecte al servidor.

func send(_msg: Dictionary) -> void:
	push_error("NetTransport.send() no implementado")


## Bombeo por frame: los transports basados en sockets lo usan; el local no.
func poll(_delta: float) -> void:
	pass


func is_open() -> bool:
	return true


func close() -> void:
	pass