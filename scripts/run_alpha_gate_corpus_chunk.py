#!/usr/bin/env python3
"""Run one bounded Alpha corpus command and record its real process result."""

from __future__ import annotations

import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


STATUS_SCHEMA = "alpha.gate-corpus-process-status.v1"
KILL_AFTER_SECONDS = 30


def sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    try:
        with open(path, "rb") as source:
            while block := source.read(1024 * 1024):
                digest.update(block)
    except OSError:
        return ""
    return digest.hexdigest()


def option_value(arguments: list[str], option: str) -> str:
    for index, argument in enumerate(arguments[:-1]):
        if argument == option:
            return arguments[index + 1]
        if argument.startswith(option + "="):
            return argument.split("=", 1)[1]
    return ""


def write_status(path: str, payload: dict[str, Any]) -> str:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_path = tempfile.mkstemp(prefix=target.name + ".", suffix=".tmp", dir=target.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            json.dump(payload, output, sort_keys=True, separators=(",", ":"))
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary_path, target)
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)
    return sha256_file(path)


def main(argv: list[str]) -> int:
    if len(argv) < 4:
        print(
            "usage: run_alpha_gate_corpus_chunk.py TIMEOUT_SECONDS ABSOLUTE_OUTPUT [--timeout-executable PATH] -- COMMAND [ARG ...]",
            file=sys.stderr,
        )
        return 2
    try:
        timeout_seconds = int(argv[0])
    except ValueError:
        print("TIMEOUT_SECONDS must be a positive integer", file=sys.stderr)
        return 2
    output_path = os.path.abspath(argv[1])
    timeout_path = shutil.which("timeout")
    if argv[2] == "--timeout-executable":
        if len(argv) < 6 or argv[4] != "--":
            print(
                "usage: run_alpha_gate_corpus_chunk.py TIMEOUT_SECONDS ABSOLUTE_OUTPUT [--timeout-executable PATH] -- COMMAND [ARG ...]",
                file=sys.stderr,
            )
            return 2
        timeout_path = argv[3]
        command_argv = argv[5:]
    elif argv[2] == "--":
        command_argv = argv[3:]
    else:
        print(
            "usage: run_alpha_gate_corpus_chunk.py TIMEOUT_SECONDS ABSOLUTE_OUTPUT [--timeout-executable PATH] -- COMMAND [ARG ...]",
            file=sys.stderr,
        )
        return 2
    if timeout_seconds < 1 or not command_argv:
        print("A positive timeout and a command are required", file=sys.stderr)
        return 2
    recorded_output = option_value(command_argv, "--output")
    if not recorded_output or os.path.abspath(recorded_output) != output_path:
        print("ABSOLUTE_OUTPUT must match the corpus command's --output value", file=sys.stderr)
        return 2

    status_path = output_path + ".status.json"
    if os.path.exists(status_path):
        print(f"Refusing to overwrite process status {status_path}", file=sys.stderr)
        return 2

    timeout_version = ""
    timeout_implementation = "NOT_FOUND"
    process_exit_code = 127
    error = ""
    timeout_command_argv = [
        timeout_path or "timeout",
        "--signal=TERM",
        f"--kill-after={KILL_AFTER_SECONDS}s",
        str(timeout_seconds),
        *command_argv,
    ]
    if timeout_path and (not os.path.isabs(timeout_path) or not os.path.isfile(timeout_path)):
        timeout_implementation = "INVALID_TIMEOUT_PATH"
        error = "the timeout executable path must name an existing absolute file"
    elif timeout_path:
        version_result = subprocess.run([timeout_path, "--version"], check=False, capture_output=True, text=True)
        timeout_version = (version_result.stdout or version_result.stderr).splitlines()[0] if (version_result.stdout or version_result.stderr) else ""
        if version_result.returncode != 0 or "GNU coreutils" not in timeout_version:
            timeout_implementation = "NON_GNU_TIMEOUT"
            error = "the installed timeout command is not GNU coreutils timeout"
        else:
            timeout_implementation = "GNU coreutils timeout"
            try:
                result = subprocess.run(
                    timeout_command_argv,
                    check=False,
                    timeout=timeout_seconds + KILL_AFTER_SECONDS + 10,
                )
                process_exit_code = int(result.returncode)
            except subprocess.TimeoutExpired:
                process_exit_code = 124
                error = "launcher watchdog expired while waiting for GNU timeout"
    else:
        error = "GNU timeout was not found on PATH"

    report_path = option_value(command_argv, "--report-output")
    output_sha256 = sha256_file(output_path)
    report_output_sha256 = sha256_file(report_path) if report_path else ""
    if process_exit_code == 0 and not output_sha256:
        process_exit_code = 74
        error = "the corpus output could not be hashed after a zero exit"
    if process_exit_code == 0 and report_path and not report_output_sha256:
        process_exit_code = 74
        error = "the corpus report could not be hashed after a zero exit"
    payload: dict[str, Any] = {
        "schema": STATUS_SCHEMA,
        "timeout_implementation": timeout_implementation,
        "timeout_version": timeout_version,
        "timeout_executable_path": timeout_path or "",
        "timeout_seconds": timeout_seconds,
        "kill_after_seconds": KILL_AFTER_SECONDS,
        "process_exit_code": process_exit_code,
        "error": error,
        "command_argv": timeout_command_argv,
        "command": shlex.join(timeout_command_argv),
        "output_path": output_path,
        "output_sha256": output_sha256,
        "report_output_path": os.path.abspath(report_path) if report_path else "",
        "report_output_sha256": report_output_sha256,
    }
    status_sha256 = write_status(status_path, payload)
    print(
        "CORPUS_PROCESS_STATUS "
        f"sidecar={status_path} sidecar_sha256={status_sha256} "
        f"exit_code={process_exit_code} output_sha256={payload['output_sha256']} "
        f"report_sha256={payload['report_output_sha256']}"
    )
    return process_exit_code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
