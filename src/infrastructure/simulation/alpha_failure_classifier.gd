class_name AlphaFailureClassifier
extends RefCounted

const VALID_OUTCOMES := ["VICTORY", "DEFEAT"]

static func classify(attempt: Dictionary) -> Dictionary:
	var failure_classification := "NONE"
	var detail := ""
	if bool(attempt.get("crash_detected", false)):
		failure_classification = "CRASH"
		detail = str(attempt.get("failure_detail", "Simulation process crashed."))
	elif not bool(attempt.get("authoritative_state_valid", true)):
		failure_classification = "INVALID_AUTHORITATIVE_STATE"
		detail = str(attempt.get("failure_detail", "Run state failed an authoritative invariant check."))
	elif bool(attempt.get("soft_lock_detected", false)):
		failure_classification = "SOFT_LOCK"
		detail = str(attempt.get("failure_detail", "The policy made no terminal progress before its command limit."))
	elif str(attempt.get("replay_status", "")) == "DIVERGED":
		failure_classification = "REPLAY_DIVERGENCE"
		detail = str(attempt.get("failure_detail", "The captured accepted-command trace did not replay deterministically."))
	elif str(attempt.get("replay_status", "")) == "UNAVAILABLE":
		failure_classification = "REPLAY_UNAVAILABLE"
		detail = str(attempt.get("failure_detail", "The required replay version or content bundle is unavailable."))
	elif bool(attempt.get("command_rejected", false)):
		failure_classification = "COMMAND_REJECTED"
		detail = str(attempt.get("failure_detail", "The simulation policy submitted an invalid authoritative command."))
	elif not bool(attempt.get("content_available", true)):
		failure_classification = "CONTENT_UNAVAILABLE"
		detail = str(attempt.get("failure_detail", "A scheduled Character or Contract is not present in this content bundle."))
	elif not bool(attempt.get("terminal", false)):
		failure_classification = "INCOMPLETE_RUN"
		detail = str(attempt.get("failure_detail", "The simulation stopped before a valid Run ending."))
	elif str(attempt.get("outcome", "")) not in VALID_OUTCOMES:
		failure_classification = "INVALID_TERMINAL_OUTCOME"
		detail = str(attempt.get("failure_detail", "The terminal Run outcome is not Victory or Defeat."))
	return {
		"failure_classification": failure_classification,
		"valid_gameplay_outcome": failure_classification == "NONE",
		"outcome": str(attempt.get("outcome", "")),
		"detail": detail,
	}
