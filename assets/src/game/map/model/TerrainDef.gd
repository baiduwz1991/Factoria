class_name TerrainDef
extends RefCounted

var id: StringName = &""
var numeric_id: int = 0
var display_name: String = ""
var map_color: int = 0xffffff
var walkable: bool = true
var buildable: bool = true
var is_water: bool = false
var aliases: Array[StringName] = []
var source_mod_id: StringName = &"core"
var preferred_runtime_id: int = 0
