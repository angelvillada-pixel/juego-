class_name GameMenu
extends Control
## Menú principal (Punto 4): título, selectores de modo/armadura/mapa,
## volúmenes y botón Jugar. Construido por código (sin escena).
## La selección pre-partida no viola "loadout solo cambia al morir"
## (se elige antes de spawnear).

signal start_requested(mode_id: String, armor_id: String, map_id: String)
signal join_requested(address: String)

var mode_opt: OptionButton
var armor_opt: OptionButton
var map_opt: OptionButton
var sfx_slider: HSlider
var music_slider: HSlider
var callsign_edit: LineEdit
var address_edit: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(360, 0)
	add_child(box)

	var title := Label.new()
	title.text = "BETWEEN WORLDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Aegis vs Rift — prototipo jugable"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.6)
	box.add_child(sub)

	mode_opt = _labeled_option(box, "Mode", ModeData.ORDER)
	armor_opt = _labeled_option(box, "Armor", ArmorData.ORDER)
	map_opt = _labeled_option(box, "Map", MapData.ORDER)

	sfx_slider = _labeled_slider(box, "SFX volume", 0.8)
	music_slider = _labeled_slider(box, "Music volume", 0.5)
	sfx_slider.value = Audio.sfx_volume
	music_slider.value = Audio.music_volume

	var start_btn := Button.new()
	start_btn.text = "DEPLOY  (Enter)"
	start_btn.custom_minimum_size = Vector2(0, 44)
	start_btn.pressed.connect(_on_start)
	box.add_child(start_btn)

	callsign_edit = _labeled_edit(box, "Callsign", 16)
	callsign_edit.text = Backend.get_callsign()
	address_edit = _labeled_edit(box, "Server", 64)
	var recents: Array = Backend.get_recents()
	address_edit.text = str(recents[0]) if not recents.is_empty() else ""
	var join_btn := Button.new()
	join_btn.text = "JOIN SERVER"
	join_btn.pressed.connect(_on_join)
	box.add_child(join_btn)

	var hint := Label.new()
	hint.text = "WASD move · Space jump · LMB fire · F/G build · E dash · Tab scores · Esc pause"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)


func _labeled_option(parent: Control, label_text: String, ids: Array) -> OptionButton:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	var lab := Label.new()
	lab.text = label_text
	lab.custom_minimum_size = Vector2(90, 0)
	row.add_child(lab)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(220, 0)
	for id in ids:
		opt.add_item(_display_name(label_text, str(id)), opt.item_count)
		opt.set_item_metadata(opt.item_count - 1, str(id))
	row.add_child(opt)
	return opt


func _display_name(kind: String, id: String) -> String:
	match kind:
		"Mode":
			return str(ModeData.get_def(id)["display_name"])
		"Armor":
			return str(ArmorData.get_def(id)["display_name"])
		"Map":
			return str(MapData.get_def(id)["display_name"])
	return id


func _labeled_slider(parent: Control, label_text: String, initial: float) -> HSlider:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	var lab := Label.new()
	lab.text = label_text
	lab.custom_minimum_size = Vector2(90, 0)
	row.add_child(lab)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(220, 0)
	row.add_child(slider)
	return slider


func _labeled_edit(parent: Control, label_text: String, max_len: int) -> LineEdit:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	var lab := Label.new()
	lab.text = label_text
	lab.custom_minimum_size = Vector2(90, 0)
	row.add_child(lab)
	var edit := LineEdit.new()
	edit.max_length = max_len
	edit.custom_minimum_size = Vector2(220, 0)
	row.add_child(edit)
	return edit


func selected_mode() -> String:
	return str(mode_opt.get_item_metadata(mode_opt.selected))


func selected_armor() -> String:
	return str(armor_opt.get_item_metadata(armor_opt.selected))


func selected_map() -> String:
	return str(map_opt.get_item_metadata(map_opt.selected))


func apply_volumes() -> void:
	Audio.set_sfx_volume(float(sfx_slider.value))
	Audio.set_music_volume(float(music_slider.value))


func _on_start() -> void:
	apply_volumes()
	Backend.set_callsign(callsign_edit.text)
	emit_signal("start_requested", selected_mode(), selected_armor(), selected_map())


func _on_join() -> void:
	apply_volumes()
	Backend.set_callsign(callsign_edit.text)
	Backend.add_recent(address_edit.text)
	emit_signal("join_requested", address_edit.text.strip_edges())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_round"):
		_on_start()
		get_viewport().set_input_as_handled()
