class_name DeterministicRngStream
extends RefCounted

const SNAPSHOT_VERSION := 1

var stream_id: String
var _rng: RandomNumberGenerator

func _init(root_seed: int, domain_id: String) -> void:
	stream_id = domain_id
	_rng = RandomNumberGenerator.new()
	_rng.seed = _derive_seed(root_seed, domain_id)

func next_int(minimum: int, maximum: int) -> int:
	return _rng.randi_range(minimum, maximum)

func snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"stream_id": stream_id,
		"state": _rng.state,
	}

func restore(saved_state: Dictionary) -> bool:
	if saved_state.get("version", -1) != SNAPSHOT_VERSION:
		return false
	if saved_state.get("stream_id", "") != stream_id:
		return false
	if typeof(saved_state.get("state")) != TYPE_INT:
		return false

	_rng.state = int(saved_state["state"])
	return true

func _derive_seed(root_seed: int, domain_id: String) -> int:
	var domain_hash: int = 2166136261
	for byte in domain_id.to_utf8_buffer():
		domain_hash = int((domain_hash ^ int(byte)) * 16777619) % 2147483647
	if domain_hash == 0:
		domain_hash = 1

	var normalized_root_seed := root_seed % 2147483647
	if normalized_root_seed < 0:
		normalized_root_seed += 2147483647
	var derived_seed := (normalized_root_seed * 48271 + domain_hash) % 2147483647
	return 1 if derived_seed == 0 else derived_seed
