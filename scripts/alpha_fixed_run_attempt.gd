extends SceneTree

const SimulationManifestScript = preload("res://src/infrastructure/simulation/simulation_manifest.gd")
const AlphaSimulationRunnerScript = preload("res://src/infrastructure/simulation/alpha_simulation_runner.gd")
const Phase2CatalogScript = preload("res://src/content/catalogs/phase_2_catalog.gd")

const BENCHMARK_ID := "alpha.fixed-complete-run.v1"
const GATE_ID := "hardening"
const SEED := 8803
const POLICY_ID := "Hybrid"
const CHARACTER_ID := "base.character.sequence"
const CONTRACT_ID := "base.contract.pressure"
const ROUTE_ID := "EVENT"
const COMMAND_LIMIT := 1024
const RESULT_PREFIX := "ALPHA_FIXED_RUN_RESULT "

static func fixed_workload_definition() -> Dictionary:
	var config := {
		"schema_version": 1,
		"content_version": "content.slice.v2",
		"gate_profiles": [{
			"gate_id": GATE_ID,
			"attempt_count": 1,
			"seed_start": SEED,
			"policy_ids": [POLICY_ID],
			"character_ids": [CHARACTER_ID],
			"contract_ids": [CONTRACT_ID],
			"route_ids": [ROUTE_ID],
		}],
	}
	var manifest = SimulationManifestScript.new(config, Phase2CatalogScript.CHARACTER_IDS, Phase2CatalogScript.CONTRACT_IDS)
	if not manifest.is_valid():
		return {"benchmark_error": "Fixed benchmark manifest is invalid: %s" % str(manifest.errors())}

	var gate: Dictionary = manifest.to_dictionary().get("gates", {}).get(GATE_ID, {})
	var cases: Array = gate.get("cases", [])
	if cases.size() != 1:
		return {"benchmark_error": "Fixed benchmark manifest did not produce exactly one attempt case."}

	var attempt_case: Dictionary = cases[0]
	var manifest_hash: String = manifest.manifest_hash()
	return {
		"benchmark_id": BENCHMARK_ID,
		"workload": {
			"gate_id": GATE_ID,
			"seed": SEED,
			"policy_id": POLICY_ID,
			"character_id": CHARACTER_ID,
			"contract_id": CONTRACT_ID,
			"route_id": ROUTE_ID,
			"command_limit": COMMAND_LIMIT,
			"manifest_hash": manifest_hash,
			"attempt_case": attempt_case,
		},
	}

static func run_fixed_attempt() -> Dictionary:
	var result := fixed_workload_definition()
	if result.has("benchmark_error"):
		return result
	var workload: Dictionary = result["workload"]
	var attempt_case: Dictionary = workload["attempt_case"]
	var attempt: Dictionary = AlphaSimulationRunnerScript.new().run_attempt(
		attempt_case,
		str(workload["manifest_hash"]),
		int(workload["command_limit"]),
	)
	result["attempt"] = attempt
	return result

func _initialize() -> void:
	var result := run_fixed_attempt()
	if result.has("benchmark_error"):
		push_error(str(result.get("benchmark_error", "Fixed benchmark failed.")))
		quit(1)
		return
	print(RESULT_PREFIX + JSON.stringify(result))
	quit(0)
