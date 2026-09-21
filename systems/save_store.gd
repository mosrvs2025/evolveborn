extends RefCounted

const PATH = "user://hollow_v1.json"

static func write_save(data: Dictionary, path: String = PATH) -> bool:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

static func read_save(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("version",0) != 1: return {}
	return parsed
