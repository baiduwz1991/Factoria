class_name RoleCreateLayer
extends BaseUI

#region 配置与常量
const PERSONALITY_OPTIONS: Array[String] = [
	"沉稳",
	"热血",
	"机敏"
]

@export var title_text: String = "创建角色"
#endregion

#region 状态
var _slot_id: int = 1
var _is_submitting: bool = false
var _role_create_controller: RoleCreateController = null
var _pending_name: String = ""
var _pending_personality: String = ""
#endregion

#region 节点引用
@export var title_label_path: NodePath
@export var slot_label_path: NodePath
@export var name_input_path: NodePath
@export var personality_option_path: NodePath
@export var planet_preset_option_path: NodePath
@export var planet_seed_input_path: NodePath
@export var random_seed_button_path: NodePath
@export var start_button_path: NodePath
@export var back_button_path: NodePath
@export var confirm_dialog_path: NodePath

@onready var title_label: Label = get_node(title_label_path) as Label
@onready var slot_label: Label = get_node(slot_label_path) as Label
@onready var name_input: LineEdit = get_node(name_input_path) as LineEdit
@onready var personality_option: OptionButton = get_node(personality_option_path) as OptionButton
@onready var planet_preset_option: OptionButton = get_node(planet_preset_option_path) as OptionButton
@onready var planet_seed_input: LineEdit = get_node(planet_seed_input_path) as LineEdit
@onready var random_seed_button: Button = get_node(random_seed_button_path) as Button
@onready var start_button: Button = get_node(start_button_path) as Button
@onready var back_button: Button = get_node(back_button_path) as Button
@onready var confirm_dialog: ConfirmationDialog = get_node(confirm_dialog_path) as ConfirmationDialog
#endregion

#region 生命周期
func on_ui_create(_params: Dictionary) -> void:
	title_label.text = title_text
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	random_seed_button.pressed.connect(_on_random_seed_pressed)
	confirm_dialog.confirmed.connect(_on_confirmed)


func on_ui_open(params: Dictionary) -> void:
	_slot_id = int(params.get("slot_id", 1))
	_is_submitting = false
	_pending_name = ""
	_pending_personality = ""
	_role_create_controller = _get_role_create_controller()
	_initialize_personality_options()
	_initialize_planet_preset_options()
	if _role_create_controller != null:
		var snapshot: Dictionary = _role_create_controller.begin_create(_slot_id)
		_slot_id = int(snapshot.get("slot_id", _slot_id))
	slot_label.text = "目标槽位：%02d" % _slot_id
	name_input.text = ""
	planet_seed_input.text = ""
	name_input.grab_focus()
	_set_interactable(true)
#endregion

#region 交互与显示
func _on_start_pressed() -> void:
	if _is_submitting:
		return
	if _role_create_controller == null:
		push_warning("RoleCreateLayer：RoleCreateController 未就绪。")
		return

	var input_name: String = name_input.text
	var selected_personality: String = personality_option.get_item_text(personality_option.selected)
	var validation: Dictionary = _role_create_controller.validate_role_input(input_name, selected_personality)
	if not bool(validation.get("ok", false)):
		push_warning("RoleCreateLayer 输入不合法：%s" % String(validation.get("error_code", "")))
		return

	_pending_name = str(validation.get("normalized_name", ""))
	_pending_personality = selected_personality
	var planet_preset_label := planet_preset_option.get_item_text(planet_preset_option.selected)
	var seed_label := planet_seed_input.text.strip_edges()
	if seed_label == "":
		seed_label = "随机"
	confirm_dialog.dialog_text = "确认以「%s / %s / %s / 种子：%s」创建角色并写入槽位%02d？" % [_pending_name, _pending_personality, planet_preset_label, seed_label, _slot_id]
	confirm_dialog.popup_centered()


func _on_confirmed() -> void:
	if _is_submitting:
		return
	if _role_create_controller == null:
		push_warning("RoleCreateLayer：RoleCreateController 未就绪。")
		return

	_is_submitting = true
	_set_interactable(false)
	_role_create_controller.request_create_role(
		_slot_id,
		_pending_name,
		_pending_personality,
		_get_selected_planet_preset_id(),
		_get_planet_seed(),
		Callable(self, "_on_create_role_saved")
	)


func _on_create_role_saved(result: Dictionary) -> void:
	_is_submitting = false
	_set_interactable(true)
	if not bool(result.get("ok", false)):
		push_warning("RoleCreateLayer 存档失败：%s" % String(result.get("error_code", "")))
		return

	var profile: Dictionary = result.get("profile", {})
	var slot_id: int = int(profile.get("slot_id", _slot_id))
	_role_create_controller.request_open_planet_after_create(get_instance_id(), slot_id)


func _on_back_pressed() -> void:
	if _is_submitting:
		return
	if _role_create_controller != null:
		_role_create_controller.request_close_ui(get_instance_id())


func _on_random_seed_pressed() -> void:
	planet_seed_input.text = str(randi_range(1, 2147483647))
#endregion

#region 内部逻辑
func _initialize_personality_options() -> void:
	personality_option.clear()
	var options: Array[String] = []
	if _role_create_controller != null:
		options = _role_create_controller.get_personality_options()
	for option in options:
		personality_option.add_item(option)
	if personality_option.item_count == 0:
		personality_option.add_item("沉稳")
	personality_option.select(0)


func _initialize_planet_preset_options() -> void:
	planet_preset_option.clear()
	if _role_create_controller != null:
		for option in _role_create_controller.get_planet_preset_options():
			var label := str(option.get("label", ""))
			var description := str(option.get("description", ""))
			if description != "":
				label = "%s（%s）" % [label, description]
			planet_preset_option.add_item(label)
			planet_preset_option.set_item_metadata(planet_preset_option.item_count - 1, option.get("id", &"standard"))
	if planet_preset_option.item_count == 0:
		planet_preset_option.add_item("标准")
		planet_preset_option.set_item_metadata(0, &"standard")
	planet_preset_option.select(0)


func _set_interactable(enabled: bool) -> void:
	name_input.editable = enabled
	personality_option.disabled = not enabled
	planet_preset_option.disabled = not enabled
	planet_seed_input.editable = enabled
	random_seed_button.disabled = not enabled
	start_button.disabled = not enabled
	back_button.disabled = not enabled


func _get_selected_planet_preset_id() -> StringName:
	if planet_preset_option.selected < 0:
		return &"standard"
	return StringName(planet_preset_option.get_item_metadata(planet_preset_option.selected))


func _get_planet_seed() -> int:
	var text := planet_seed_input.text.strip_edges()
	if text == "":
		return 0
	if not text.is_valid_int():
		return hash(text)
	return int(text)


func _get_role_create_controller() -> RoleCreateController:
	return _get_or_register_controller(
		RoleCreateController.CONTROLLER_ID,
		func() -> BaseController:
			return RoleCreateController.new()
	) as RoleCreateController
#endregion
