class_name ModsLayer
extends BaseUI

@export var list_path: NodePath
@export var status_label_path: NodePath
@export var reload_button_path: NodePath
@export var back_button_path: NodePath

@onready var list: VBoxContainer = get_node(list_path) as VBoxContainer
@onready var status_label: Label = get_node(status_label_path) as Label
@onready var reload_button: Button = get_node(reload_button_path) as Button
@onready var back_button: Button = get_node(back_button_path) as Button


func on_ui_create(_params: Dictionary) -> void:
	reload_button.pressed.connect(_on_reload_pressed)
	back_button.pressed.connect(_on_back_pressed)


func on_ui_open(_params: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	_clear_list()
	var mod_manager: Node = _get_mod_manager()
	if mod_manager == null:
		status_label.text = "ModManager missing."
		return

	var mods: Array = mod_manager.call("get_mod_list_snapshot") as Array
	for raw_mod in mods:
		if raw_mod is Dictionary:
			_add_mod_row(raw_mod as Dictionary)

	var diagnostics: Array = mod_manager.call("get_mod_diagnostics") as Array
	status_label.text = "Loaded %d mod(s). Diagnostics: %d" % [mods.size(), diagnostics.size()]


func _add_mod_row(mod_info: Dictionary) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 42)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var enabled_box: CheckBox = CheckBox.new()
	enabled_box.button_pressed = bool(mod_info.get("enabled", false))
	enabled_box.disabled = bool(mod_info.get("locked", false))
	enabled_box.toggled.connect(func(is_enabled: bool) -> void:
		_on_enabled_toggled(StringName(mod_info.get("id", "")), is_enabled)
	)
	row.add_child(enabled_box)

	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = _build_mod_label(mod_info)
	row.add_child(label)

	var up_button: Button = Button.new()
	up_button.text = "Up"
	up_button.disabled = bool(mod_info.get("locked", false)) or not bool(mod_info.get("enabled", false))
	up_button.pressed.connect(func() -> void:
		_on_move_pressed(StringName(mod_info.get("id", "")), -1)
	)
	row.add_child(up_button)

	var down_button: Button = Button.new()
	down_button.text = "Down"
	down_button.disabled = bool(mod_info.get("locked", false)) or not bool(mod_info.get("enabled", false))
	down_button.pressed.connect(func() -> void:
		_on_move_pressed(StringName(mod_info.get("id", "")), 1)
	)
	row.add_child(down_button)

	list.add_child(row)


func _build_mod_label(mod_info: Dictionary) -> String:
	var label: String = "%s  %s" % [str(mod_info.get("name", "")), str(mod_info.get("version", ""))]
	var mod_id: String = str(mod_info.get("id", ""))
	if mod_id != "":
		label = "%s  (%s)" % [label, mod_id]
	var errors: Array = mod_info.get("errors", []) as Array
	if errors != null and not errors.is_empty():
		label = "%s  ERR: %s" % [label, _join_strings(errors)]
	return label


func _join_strings(values: Array) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for value in values:
		texts.append(str(value))
	return ", ".join(texts)


func _clear_list() -> void:
	for child in list.get_children():
		child.queue_free()


func _on_enabled_toggled(mod_id: StringName, enabled: bool) -> void:
	var mod_manager: Node = _get_mod_manager()
	if mod_manager != null:
		mod_manager.call("set_mod_enabled", mod_id, enabled)
	_refresh()


func _on_move_pressed(mod_id: StringName, direction: int) -> void:
	var mod_manager: Node = _get_mod_manager()
	if mod_manager != null:
		mod_manager.call("move_mod", mod_id, direction)
	_refresh()


func _on_reload_pressed() -> void:
	var mod_manager: Node = _get_mod_manager()
	if mod_manager != null:
		mod_manager.call("reload_mods")
	_refresh()


func _on_back_pressed() -> void:
	UIManager.open_ui(UIRegistry.START_GAME_LAYER, {}, UIManager.MODE_REPLACE)


func _get_mod_manager() -> Node:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null or scene_tree.root == null:
		return null
	return scene_tree.root.get_node_or_null("ModManager")
