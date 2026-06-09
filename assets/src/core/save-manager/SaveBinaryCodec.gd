class_name SaveBinaryCodec
extends RefCounted

#region 对外接口
func encode(_snapshot: Dictionary) -> PackedByteArray:
	# 阶段 B 接入：当前先保留占位，避免调用方硬编码具体 codec。
	return PackedByteArray()


func decode(_binary: PackedByteArray) -> Dictionary:
	return {
		"ok": false,
		"error_code": &"binary_codec_not_ready",
		"error_message": "SaveBinaryCodec 尚未接入。"
	}
#endregion
