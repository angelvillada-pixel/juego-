class_name NetMsg
## Tipos de mensaje de la capa de red de Between Worlds.
## Direcciones: INTENTOS van cliente→servidor; EVENTOS van servidor→cliente.
## Payloads solo con datos primitivos (sin referencias a nodos) para ser
## serializables por NetCodec en la Etapa 3+ (WebSocket/WebRTC).

# ---- Intents (cliente -> servidor)
# Punto 3: todo intent lleva `seq` (nº secuencia, lo pone Client.send) y `t`
# (ms de envío). FIRE/MOVE/UTILITY llevan además `ftick` (último tick de
# servidor visto por el cliente, para lag-compensación).
# S1: todo intent lleva además `proto` (versión de protocolo, lo pone
# Client.send). Las sesiones de red exigen coincidencia exacta o se dropean.
const PROTOCOL_VERSION := 1
const FIRE := "fire"                # {type, weapon_index:int, direction:Vector2}
const RELOAD := "reload"            # {type, weapon_index:int}
const BUILD_PLACE := "build_place"  # {type, cell:Vector2i}
const BUILD_DESTROY := "build_destroy"  # {type, cell:Vector2i}
const PICKUP_CLAIM := "pickup_claim"  # {type, path:String relativa al mundo registrado}
const FALL_OUT := "fall_out"        # {type}
const MOVE := "move"                # {type, axis:float, jump_edge:bool, crouch:bool, aim:float}
const UTILITY := "utility"          # {type, direction:Vector2} provisional Punto 1: Dash
# S3: autenticación previa al spawn (solo sesiones de red en dedicado).
const AUTH_REGISTER := "auth_register"  # {type, callsign:String, password:String}
const AUTH_LOGIN := "auth_login"        # {type, callsign:String, password:String}
const JOIN := "join"                    # {type, token:String, callsign:String}

const INTENTS := [FIRE, RELOAD, BUILD_PLACE, BUILD_DESTROY, PICKUP_CLAIM, FALL_OUT, MOVE, UTILITY, AUTH_REGISTER, AUTH_LOGIN, JOIN]

# ---- Eventos (servidor -> cliente)
# Punto 3: SNAPSHOT lleva `tick` (tick del servidor) y `acks` ({id: último seq}).
const WELCOME := "welcome"            # {type, id:int, spawn:[x,y], team:int, proto:int}
const SNAPSHOT := "snapshot"          # {type, players:{...}, tick:int, acks:{id:seq}}
const BLOCK_ADDED := "block_added"    # {type, cell:[x,y], block_id:String, team:int}
const BLOCK_REMOVED := "block_removed"  # {type, cell:[x,y]}
const PICKUP_CONSUMED := "pickup_consumed"  # {type, path:String}
const PLAYER_DIED := "player_died"    # {type, id:int, lives:int}
const PLAYER_RESPAWNED := "player_respawned"  # {type, id:int, spawn:[x,y]}
const TARGET_DESTROYED := "target_destroyed"  # {type, remaining:int, total:int}
const ROUND_WON := "round_won"        # {type}
const ROUND_LOST := "round_lost"      # {type}
const VIP_DOWN := "vip_down"          # {type, team:int} provisional Punto 2
const SCORE := "score"                # {type, scores:{team:int}} provisional Punto 2
const MODE_STATE := "mode_state"      # {type, mode:String} provisional Punto 2
const AUTH_OK := "auth_ok"            # {type, token:String, callsign:String} S3
const AUTH_FAIL := "auth_fail"        # {type, reason:String} S3

const EVENTS := [WELCOME, SNAPSHOT, BLOCK_ADDED, BLOCK_REMOVED, PICKUP_CONSUMED, PLAYER_DIED, PLAYER_RESPAWNED, TARGET_DESTROYED, ROUND_WON, ROUND_LOST, VIP_DOWN, SCORE, MODE_STATE, AUTH_OK, AUTH_FAIL]

const ALL := INTENTS + EVENTS


static func is_valid_type(t: Variant) -> bool:
	return t is String and ALL.has(t)


static func is_intent(t: Variant) -> bool:
	return t is String and INTENTS.has(t)


static func is_event(t: Variant) -> bool:
	return t is String and EVENTS.has(t)


## S1/P1-P2: envío de intents sin referencia estática al autoload Client.
## Los scripts que también carga el dedicado (player.gd, pickup.gd) no pueden
## nombrar `Client` en compilación con `-s`; se resuelve en runtime y funciona
## igual en partida local, cliente de red y servidor (aquí no hay Client).
static func send_intent(msg: Dictionary) -> bool:
	var client := _client_node()
	if client == null:
		return false
	return bool(client.send(msg))


## Reloj del peer visto por el cliente (0 fuera de partida en red).
static func client_peer_tick() -> int:
	var client := _client_node()
	if client == null:
		return 0
	var v: Variant = client.get("peer_tick")
	if v is int:
		return v
	if v is float:
		return int(v)
	return 0


static func _client_node() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	var tree := loop as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Client")
