class_name RemotePuppet
extends Node2D
## Representación visual de un jugador REMOTO controlada por snapshots del
## servidor (Etapa 3). Sin física ni lógica.
##
## Punto 3: interpolación — el snapshot fija un objetivo y `_process` se
## acerca con suavizado exponencial (>= 100 ms de interpolación efectiva);
## snap duro solo si la deriva supera el umbral (teleport/respawn).

const SNAP_DISTANCE := 96.0
const SMOOTH_RATE := 12.0  # ~120 ms de convergencia

var player_id := 0
var team_id := 0
var armor_id := ArmorData.ARMOR_MEDIUM
var aim := 0.0
var alive := true

var _target := Vector2.ZERO
var _has_target := false

const WIDTH := 12.0
const HEIGHT := 24.0


func apply_state(data: Dictionary) -> void:
	var p: Array = data.get("p", [global_position.x, global_position.y])
	_target = Vector2(p[0], p[1])
	if not _has_target or global_position.distance_to(_target) > SNAP_DISTANCE:
		global_position = _target
		_has_target = true
	armor_id = str(data.get("armor", armor_id))
	aim = float(data.get("aim", aim))
	alive = bool(data.get("alive", alive))
	team_id = int(data.get("team", team_id))
	visible = alive
	queue_redraw()


func _process(delta: float) -> void:
	if not _has_target:
		return
	var d := global_position.distance_to(_target)
	if d <= 0.5:
		global_position = _target
		return
	if d > SNAP_DISTANCE:
		global_position = _target
		return
	var t := 1.0 - exp(-SMOOTH_RATE * delta)
	global_position = global_position.lerp(_target, t)


func _draw() -> void:
	PawnArt.draw_pawn(self, WIDTH, HEIGHT, armor_id, team_id, false)
	# Brazo/arma orientada al aim del snapshot.
	var dir := Vector2.from_angle(aim)
	draw_line(Vector2.ZERO, dir * 18.0, Color(0.1, 0.1, 0.1), 3.0)
