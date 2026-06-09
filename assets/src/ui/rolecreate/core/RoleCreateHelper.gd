class_name RoleCreateHelper
extends RefCounted

static func normalize_player_name(raw_name: String) -> String:
	return raw_name.strip_edges()


static func validate_role_input(
	raw_name: String,
	personality: String,
	personality_options: Array[String],
	error_player_name_empty: StringName,
	error_personality_invalid: StringName
) -> Dictionary:
	var normalized_name: String = normalize_player_name(raw_name)
	if normalized_name == "":
		return {
			"ok": false,
			"error_code": error_player_name_empty,
			"normalized_name": ""
		}

	if not personality_options.has(personality):
		return {
			"ok": false,
			"error_code": error_personality_invalid,
			"normalized_name": normalized_name
		}

	return {
		"ok": true,
		"error_code": StringName(),
		"normalized_name": normalized_name
	}


static func build_error_result(error_code: StringName) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code
	}
