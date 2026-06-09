class_name SerializeUtils
extends RefCounted

# 通用序列化辅助方法集合，被各 model / SaveData 复用以避免相同的 _parse_*
# / *_to_array 方法在每个文件里重复实现。所有 API 均为 static，不持运行时状态。

#region Vector2i
static func parse_vector2i(value: Variant, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		var raw: Dictionary = value as Dictionary
		return Vector2i(int(raw.get("x", fallback.x)), int(raw.get("y", fallback.y)))
	if value is Array:
		var raw_array: Array = value as Array
		if raw_array.size() >= 2:
			return Vector2i(int(raw_array[0]), int(raw_array[1]))
	return fallback


static func vector2i_to_dict(value: Vector2i) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y
	}
#endregion

#region StringName 数组
static func parse_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not (value is Array):
		return result
	for item in value:
		result.append(StringName(str(item)))
	return result


static func string_name_array_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
#endregion

#region Dictionary
static func parse_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func parse_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result
#endregion

#region Packed 数组
static func packed_int32_to_array(value: PackedInt32Array) -> Array[int]:
	var result: Array[int] = []
	for item in value:
		result.append(item)
	return result


static func parse_packed_int32(value: Variant) -> PackedInt32Array:
	var result := PackedInt32Array()
	if not (value is Array):
		return result
	for item in value:
		result.append(int(item))
	return result


static func packed_byte_to_array(value: PackedByteArray) -> Array[int]:
	var result: Array[int] = []
	for item in value:
		result.append(item)
	return result


static func parse_packed_byte(value: Variant) -> PackedByteArray:
	var result := PackedByteArray()
	if not (value is Array):
		return result
	for item in value:
		result.append(int(item))
	return result
#endregion
