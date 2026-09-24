#!/usr/bin/env python3
"""Run five measured repetitions of the fixed headless Alpha complete Run."""

from __future__ import annotations

import hashlib
import json
import math
import os
import platform
import shutil
import statistics
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


REPETITIONS = 5
RESULT_PREFIX = "ALPHA_FIXED_RUN_RESULT "
GODOT_VERSION_PREFIX = "4.7.2.stable."
DETERMINISM_FIELDS = (
    "accepted_commands",
    "checkpoint_hashes",
    "rng_snapshots",
    "events",
    "strategy",
    "terminal",
    "outcome",
    "two_act_profile",
    "configured_act_count",
    "act_reached",
    "progress_status",
    "unavailable_content_paths",
    "replay_status",
    "failure_classification",
)


def fail(message: str, details: str = "") -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    if details:
        print(details.rstrip(), file=sys.stderr)
    raise SystemExit(2)


def locate_godot() -> Path:
    configured = os.environ.get("GODOT_BIN", "").strip()
    if configured:
        candidate = shutil.which(configured) if not Path(configured).exists() else configured
        if not candidate:
            fail(f"GODOT_BIN does not identify an executable: {configured}")
    else:
        candidate = None
        for name in ("godot", "godot4"):
            candidate = shutil.which(name)
            if candidate:
                break
    if not candidate:
        fail("Godot was not found. Set GODOT_BIN to an executable Godot 4.7.2 Linux binary.")

    binary = Path(candidate).expanduser().resolve()
    if binary.suffix.lower() == ".exe":
        fail("A Windows .exe cannot provide Linux per-process GNU time measurements. Use a Linux Godot binary in WSL2.")
    if not binary.is_file() or not os.access(binary, os.X_OK):
        fail(f"Godot is not an executable file: {binary}")
    return binary


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json_result(stdout: str, repetition: int) -> dict[str, Any]:
    result_lines = [line[len(RESULT_PREFIX) :] for line in stdout.splitlines() if line.startswith(RESULT_PREFIX)]
    if len(result_lines) != 1:
        fail(
            f"Godot repetition {repetition} emitted {len(result_lines)} benchmark result records; expected exactly one.",
            stdout,
        )
    try:
        value = json.loads(result_lines[0])
    except json.JSONDecodeError as error:
        fail(f"Godot repetition {repetition} emitted invalid JSON: {error}", result_lines[0])
    if not isinstance(value, dict):
        fail(f"Godot repetition {repetition} returned a non-object benchmark record.")
    return value


def validate_attempt(record: dict[str, Any], repetition: int) -> tuple[dict[str, Any], dict[str, Any]]:
    if record.get("benchmark_id") != "alpha.fixed-complete-run.v1":
        fail(f"Godot repetition {repetition} returned an unexpected benchmark ID.")
    workload = record.get("workload")
    attempt = record.get("attempt")
    if "benchmark_error" in record:
        fail(f"Godot repetition {repetition} failed: {record['benchmark_error']}")
    if not isinstance(workload, dict) or not isinstance(attempt, dict):
        fail(f"Godot repetition {repetition} omitted its workload or attempt record.")

    expected = {
        "gate_id": "hardening",
        "seed": 8803,
        "policy_id": "Hybrid",
        "character_id": "base.character.sequence",
        "contract_id": "base.contract.pressure",
        "route_id": "EVENT",
        "command_limit": 1024,
    }
    for key, value in expected.items():
        if workload.get(key) != value:
            fail(f"Godot repetition {repetition} changed fixed workload field {key!r}.")
        attempt_key = "seed" if key == "seed" else key
        if key != "command_limit" and attempt.get(attempt_key) != value:
            fail(f"Godot repetition {repetition} attempt does not match workload field {key!r}.")

    commands = attempt.get("accepted_commands")
    checkpoints = attempt.get("checkpoints")
    hashes = attempt.get("checkpoint_hashes")
    rng_snapshots = attempt.get("rng_snapshots")
    if not isinstance(commands, list) or not isinstance(checkpoints, list) or not isinstance(hashes, list):
        fail(f"Godot repetition {repetition} omitted accepted commands or checkpoint data.")
    if not isinstance(rng_snapshots, list):
        fail(f"Godot repetition {repetition} omitted RNG snapshots.")
    if attempt.get("accepted_command_count") != len(commands):
        fail(f"Godot repetition {repetition} has an inconsistent accepted-command count.")
    if len(checkpoints) != len(commands) + 1 or len(hashes) != len(checkpoints):
        fail(f"Godot repetition {repetition} has incomplete checkpoint/hash data.")
    if len(rng_snapshots) != len(checkpoints) or any(not value for value in hashes):
        fail(f"Godot repetition {repetition} has incomplete RNG snapshots or checkpoint hashes.")
    if attempt.get("two_act_profile") is not True or attempt.get("terminal") is not True:
        fail(f"Godot repetition {repetition} did not produce a terminal result under the configured two-Act profile.")
    if attempt.get("configured_act_count") != 2:
        fail(f"Godot repetition {repetition} did not record the configured two-Act profile.")
    act_reached = attempt.get("act_reached")
    if not isinstance(act_reached, int) or act_reached not in (1, 2):
        fail(f"Godot repetition {repetition} omitted its actual reached Act.")
    expected_progress = "TERMINAL_AFTER_FINAL_ACT" if act_reached == 2 else "TERMINAL_BEFORE_FINAL_ACT"
    if attempt.get("progress_status") != expected_progress:
        fail(f"Godot repetition {repetition} misreported its actual Act progress.")
    if attempt.get("outcome") not in ("VICTORY", "DEFEAT"):
        fail(f"Godot repetition {repetition} has no valid terminal gameplay outcome.")
    if attempt.get("failure_classification") != "NONE" or attempt.get("replay_status") != "MATCH":
        fail(f"Godot repetition {repetition} reported a harness failure or replay divergence.")
    if not isinstance(attempt.get("events"), list) or not attempt["events"]:
        fail(f"Godot repetition {repetition} omitted Domain events.")
    return workload, attempt


def read_time_metrics(path: Path, repetition: int) -> dict[str, float | int]:
    try:
        parts = path.read_text(encoding="ascii").split()
        if len(parts) != 4:
            raise ValueError(f"expected four GNU time fields, got {len(parts)}")
        wall, user, system = (float(value) for value in parts[:3])
        rss_kib = int(parts[3])
    except (OSError, UnicodeError, ValueError) as error:
        fail(f"Could not read honest GNU time metrics for repetition {repetition}: {error}")
    if not all(math.isfinite(value) and value >= 0 for value in (wall, user, system)) or rss_kib <= 0:
        fail(f"GNU time returned unavailable or invalid metrics for repetition {repetition}.")
    return {
        "wall_time_seconds": wall,
        "user_cpu_time_seconds": user,
        "system_cpu_time_seconds": system,
        "cpu_time_seconds": user + system,
        "peak_rss_kib": rss_kib,
    }


def main() -> int:
    time_binary = Path("/usr/bin/time")
    if not time_binary.is_file() or not os.access(time_binary, os.X_OK):
        fail("GNU /usr/bin/time is unavailable; wall, CPU, and peak RSS measurements are required.")
    time_version = subprocess.run([str(time_binary), "--version"], capture_output=True, text=True, check=False)
    if time_version.returncode != 0 or "GNU Time" not in (time_version.stdout + time_version.stderr):
        fail("/usr/bin/time is not GNU time; no substitute timing source will be used.")

    godot = locate_godot()
    try:
        version_result = subprocess.run([str(godot), "--version"], capture_output=True, text=True, timeout=10, check=False)
    except subprocess.TimeoutExpired:
        fail("The selected Godot binary did not report its version within 10 seconds.")
    godot_version = version_result.stdout.strip() or version_result.stderr.strip()
    if version_result.returncode != 0 or not godot_version.startswith(GODOT_VERSION_PREFIX):
        fail(f"Expected Godot {GODOT_VERSION_PREFIX[:-1]}, got: {godot_version or 'no version output'}")

    project_root = Path(__file__).resolve().parents[1]
    script_path = "res://scripts/alpha_fixed_run_attempt.gd"
    binary_hash = sha256_file(godot)
    kernel_release = platform.release()
    is_wsl2 = "microsoft-standard-wsl2" in kernel_release.lower() or "wsl2" in kernel_release.lower()
    if is_wsl2:
        evidence_class = "WSL2_PROCESS_TIMING_NON_DEVICE_EVIDENCE"
        evidence_note = "WSL2 process measurements are not native device gameplay measurements."
    else:
        evidence_class = "HEADLESS_PROCESS_TIMING_NON_DEVICE_EVIDENCE"
        evidence_note = "Headless process measurements are not native device gameplay measurements."

    environment = os.environ.copy()
    environment["LC_ALL"] = "C"
    environment["LANG"] = "C"
    report_repetitions: list[dict[str, Any]] = []
    reference_workload: dict[str, Any] | None = None
    reference_attempt: dict[str, Any] | None = None

    with tempfile.TemporaryDirectory(prefix="alpha-fixed-run-benchmark-") as temporary_directory:
        temporary_path = Path(temporary_directory)
        for repetition in range(1, REPETITIONS + 1):
            metrics_path = temporary_path / f"time-{repetition}.txt"
            command = [
                str(time_binary),
                "-f",
                "%e %U %S %M",
                "-o",
                str(metrics_path),
                str(godot),
                "--headless",
                "--path",
                str(project_root),
                "--script",
                script_path,
            ]
            try:
                completed = subprocess.run(
                    command,
                    capture_output=True,
                    text=True,
                    env=environment,
                    timeout=900,
                    check=False,
                )
            except subprocess.TimeoutExpired as error:
                fail(f"Godot repetition {repetition} exceeded 900 seconds; no benchmark report was produced.", str(error.stderr or ""))
            if completed.returncode != 0:
                fail(
                    f"Godot repetition {repetition} exited with status {completed.returncode}.",
                    completed.stderr + completed.stdout,
                )
            if any(marker in completed.stderr for marker in ("SCRIPT ERROR", "Parse Error", "Compile Error", "Failed to load script")):
                fail(f"Godot reported a script/load error during repetition {repetition}.", completed.stderr)

            result = read_json_result(completed.stdout, repetition)
            workload, attempt = validate_attempt(result, repetition)
            if reference_workload is None:
                reference_workload = workload
                reference_attempt = attempt
            else:
                if workload != reference_workload:
                    fail(f"Fixed workload or manifest changed during repetition {repetition}.")
                assert reference_attempt is not None
                for field in DETERMINISM_FIELDS:
                    if attempt.get(field) != reference_attempt.get(field):
                        fail(f"Repeated attempt diverged in {field!r} at repetition {repetition}.")

            metrics = read_time_metrics(metrics_path, repetition)
            report_repetitions.append(
                {
                    "repetition": repetition,
                    "seed": attempt["seed"],
                    "policy_id": attempt["policy_id"],
                    "configured_act_count": attempt["configured_act_count"],
                    "act_reached": attempt["act_reached"],
                    "progress_status": attempt["progress_status"],
                    "failure_classification": attempt["failure_classification"],
                    "unavailable_content_paths": attempt["unavailable_content_paths"],
                    "accepted_command_count": attempt["accepted_command_count"],
                    "checkpoint_count": len(attempt["checkpoints"]),
                    "checkpoint_hashes": attempt["checkpoint_hashes"],
                    "terminal": attempt["terminal"],
                    "outcome": attempt["outcome"],
                    **metrics,
                }
            )

    if sha256_file(godot) != binary_hash:
        fail("The selected Godot binary changed during the five measured repetitions.")
    if reference_workload is None or reference_attempt is None or len(report_repetitions) != REPETITIONS:
        fail("The benchmark did not produce all five measured repetitions.")

    report = {
        "benchmark_id": "alpha.fixed-complete-run.v1",
        "repetition_count": REPETITIONS,
        "workload": reference_workload,
        "build": {
            "godot_version": godot_version,
            "godot_binary_sha256": binary_hash,
        },
        "machine": {
            "system": platform.system(),
            "kernel_release": kernel_release,
            "architecture": platform.machine(),
            "platform": platform.platform(),
        },
        "measurement": {
            "evidence_class": evidence_class,
            "note": evidence_note,
            "process_scope": "One complete Godot headless process per repetition, including engine startup.",
            "cpu_time_definition": "GNU time user CPU seconds plus system CPU seconds.",
            "peak_rss_unit": "KiB, as reported by GNU time %M.",
        },
        "summary": {
            "median_wall_time_seconds": statistics.median(
                repetition["wall_time_seconds"] for repetition in report_repetitions
            ),
            "median_cpu_time_seconds": statistics.median(
                repetition["cpu_time_seconds"] for repetition in report_repetitions
            ),
            "median_peak_rss_kib": statistics.median(
                repetition["peak_rss_kib"] for repetition in report_repetitions
            ),
        },
        "device_metrics": {
            "native_pc_frame_time_p95_ms": "NOT_MEASURED",
            "native_pc_command_to_visible_feedback_p95_ms": "NOT_MEASURED",
            "steam_deck_frame_time_p95_ms": "NOT_MEASURED",
            "steam_deck_command_to_visible_feedback_p95_ms": "NOT_MEASURED",
            "status": "NOT_MEASURED",
        },
        "repetitions": report_repetitions,
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
