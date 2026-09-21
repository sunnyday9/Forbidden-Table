class_name ContentValidationReport
extends RefCounted

var issues: Array = []

func is_valid() -> bool:
	return issues.is_empty()

func add_issue(issue) -> void:
	issues.append(issue)

func has_code(issue_code: String) -> bool:
	for issue in issues:
		if issue.code == issue_code:
			return true
	return false
