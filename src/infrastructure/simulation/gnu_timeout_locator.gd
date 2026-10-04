class_name GnuTimeoutLocator
extends RefCounted

static var _cached_path := ""


static func resolve_path() -> String:
	if not _cached_path.is_empty():
		return _cached_path
	var executable_names: Array[String] = ["timeout"]
	if OS.get_name() == "Windows":
		executable_names = ["timeout.exe", "timeout"]
	var candidates: Array[String] = []
	for executable_name in executable_names:
		if OS.get_name() == "Windows":
			_append_command_paths("where.exe", PackedStringArray([executable_name]), candidates)
		_append_command_paths("which", PackedStringArray(["-a", executable_name]), candidates)
		_append_command_paths("which", PackedStringArray([executable_name]), candidates)
	for raw_path in candidates:
		var path := _native_path(raw_path)
		if path.is_absolute_path() and FileAccess.file_exists(path) and _is_gnu_timeout(path):
			_cached_path = path
			return path
	return ""


static func _append_command_paths(command: String, arguments: PackedStringArray, candidates: Array[String]) -> void:
	var output: Array[String] = []
	OS.execute(command, arguments, output, true)
	for raw_path in output:
		var path := str(raw_path).strip_edges()
		if not path.is_empty() and not candidates.has(path):
			candidates.append(path)


static func _native_path(path: String) -> String:
	if OS.get_name() != "Windows" or not path.begins_with("/"):
		return path
	var windows_path_output: Array[String] = []
	var conversion_exit_code := OS.execute("cygpath", ["-w", path], windows_path_output, true)
	if conversion_exit_code != 0 or windows_path_output.is_empty():
		return ""
	return str(windows_path_output[0]).strip_edges()


static func _is_gnu_timeout(path: String) -> bool:
	var output: Array[String] = []
	var exit_code := OS.execute(path, ["--version"], output, true)
	return exit_code == 0 and "GNU coreutils" in "\n".join(output)
