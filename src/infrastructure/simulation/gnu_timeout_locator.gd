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
	var git_executable_candidates: Array[String] = []
	for executable_name in executable_names:
		if OS.get_name() == "Windows":
			_append_command_paths("where.exe", PackedStringArray([executable_name]), candidates)
		_append_command_paths("which", PackedStringArray(["-a", executable_name]), candidates)
		_append_command_paths("which", PackedStringArray([executable_name]), candidates)
	if OS.get_name() == "Windows":
		_append_command_paths("where.exe", PackedStringArray(["git.exe"]), git_executable_candidates)
		_append_command_paths("which", PackedStringArray(["-a", "git.exe"]), git_executable_candidates)
		_append_command_paths("which", PackedStringArray(["git.exe"]), git_executable_candidates)
	_cached_path = _resolve_path_from_candidates(OS.get_name(), candidates, git_executable_candidates)
	return _cached_path


static func _resolve_path_from_candidates(
		os_name: String,
		timeout_candidates: Array[String],
		git_executable_candidates: Array[String],
		file_exists_check: Callable = Callable(),
		gnu_timeout_check: Callable = Callable()) -> String:
	for raw_path in _candidate_paths_for_platform(os_name, timeout_candidates, git_executable_candidates):
		var path := _native_path(raw_path)
		if not path.is_absolute_path():
			continue
		var path_exists := bool(file_exists_check.call(path)) if file_exists_check.is_valid() else FileAccess.file_exists(path)
		if not path_exists:
			continue
		var is_gnu_timeout := bool(gnu_timeout_check.call(path)) if gnu_timeout_check.is_valid() else _is_gnu_timeout(path)
		if is_gnu_timeout:
			return path
	return ""


static func _candidate_paths_for_platform(
		os_name: String,
		timeout_candidates: Array[String],
		git_executable_candidates: Array[String]) -> Array[String]:
	var candidates: Array[String] = []
	for path in timeout_candidates:
		if not candidates.has(path):
			candidates.append(path)
	if os_name == "Windows":
		for git_executable_path in git_executable_candidates:
			var git_root := _windows_git_root(git_executable_path)
			if git_root.is_empty():
				continue
			var bundled_timeout_path := git_root.path_join("usr").path_join("bin").path_join("timeout.exe")
			if not candidates.has(bundled_timeout_path):
				candidates.append(bundled_timeout_path)
	return candidates


static func _windows_git_root(git_executable_path: String) -> String:
	var normalized_path := git_executable_path.strip_edges().replace("\\", "/")
	var lowercase_path := normalized_path.to_lower()
	var executable_suffixes: Array[String] = [
		"/mingw64/libexec/git-core/git.exe",
		"/mingw32/libexec/git-core/git.exe",
		"/mingw64/bin/git.exe",
		"/mingw32/bin/git.exe",
		"/usr/bin/git.exe",
		"/cmd/git.exe",
		"/bin/git.exe",
	]
	for suffix in executable_suffixes:
		if lowercase_path.ends_with(suffix):
			return normalized_path.substr(0, normalized_path.length() - suffix.length())
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
