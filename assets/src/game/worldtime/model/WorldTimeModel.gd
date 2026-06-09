class_name WorldTimeModel
extends RefCounted

const HOURS_PER_DAY: float = 24.0
const MINUTES_PER_HOUR: float = 60.0
const DEFAULT_DAY_INDEX: int = 1
const DEFAULT_TIME_OF_DAY: float = 8.0
const DEFAULT_TIME_SCALE: float = 60.0

var day_index: int = DEFAULT_DAY_INDEX
var time_of_day: float = DEFAULT_TIME_OF_DAY
var time_scale: float = DEFAULT_TIME_SCALE
var paused: bool = false


func reset_to_default() -> void:
	day_index = DEFAULT_DAY_INDEX
	time_of_day = DEFAULT_TIME_OF_DAY
	time_scale = DEFAULT_TIME_SCALE
	paused = false


func advance(delta: float) -> bool:
	if paused:
		return false
	var hours_delta: float = maxf(delta, 0.0) * maxf(time_scale, 0.0) / 3600.0
	if hours_delta <= 0.0:
		return false

	var total_hours: float = time_of_day + hours_delta
	var added_days: int = floori(total_hours / HOURS_PER_DAY)
	if added_days > 0:
		day_index += added_days
	time_of_day = _wrap_hour(total_hours)
	sanitize()
	return true


func set_time_of_day(value: float) -> bool:
	var next_time: float = _wrap_hour(value)
	if is_equal_approx(time_of_day, next_time):
		return false
	time_of_day = next_time
	return true


func set_time_scale(value: float) -> bool:
	var next_scale: float = maxf(value, 0.0)
	if is_equal_approx(time_scale, next_scale):
		return false
	time_scale = next_scale
	return true


func set_paused(value: bool) -> bool:
	if paused == value:
		return false
	paused = value
	return true


func to_dict() -> Dictionary:
	return {
		"schema_version": 1,
		"day_index": day_index,
		"time_of_day": time_of_day,
		"time_scale": time_scale
	}


func from_dict(raw: Dictionary) -> void:
	if raw.is_empty():
		reset_to_default()
		return
	day_index = int(raw.get("day_index", DEFAULT_DAY_INDEX))
	time_of_day = float(raw.get("time_of_day", DEFAULT_TIME_OF_DAY))
	time_scale = float(raw.get("time_scale", DEFAULT_TIME_SCALE))
	sanitize()


func get_snapshot() -> Dictionary:
	return {
		"day_index": day_index,
		"time_of_day": time_of_day,
		"time_scale": time_scale,
		"paused": paused,
		"time_label": format_time_label()
	}


func format_time_label() -> String:
	var total_minutes: int = int(round(time_of_day * MINUTES_PER_HOUR)) % int(HOURS_PER_DAY * MINUTES_PER_HOUR)
	var hour: int = total_minutes / int(MINUTES_PER_HOUR)
	var minute: int = total_minutes % int(MINUTES_PER_HOUR)
	return "第 %d 天 %02d:%02d" % [day_index, hour, minute]


func sanitize() -> void:
	day_index = maxi(day_index, DEFAULT_DAY_INDEX)
	time_of_day = _wrap_hour(time_of_day)
	time_scale = maxf(time_scale, 0.0)


func _wrap_hour(value: float) -> float:
	return fposmod(value, HOURS_PER_DAY)
