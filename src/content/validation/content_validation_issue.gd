class_name ContentValidationIssue
extends RefCounted

var code: String
var content_id: String
var reference_id: String
var message: String

func _init(issue_code: String, issue_content_id: String, issue_message: String, issue_reference_id: String = "") -> void:
	code = issue_code
	content_id = issue_content_id
	reference_id = issue_reference_id
	message = issue_message

func to_dictionary() -> Dictionary:
	return {
		"code": code,
		"content_id": content_id,
		"reference_id": reference_id,
		"message": message,
	}
