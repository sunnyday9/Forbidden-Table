#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_version="4.7.2"
godot_binary="${GODOT_BIN:-}"
download_timeout_seconds=120
test_timeout_seconds=600

if ! command -v timeout >/dev/null 2>&1; then
  echo "ERROR: the test wrapper requires the 'timeout' command to bound Godot and download execution." >&2
  exit 2
fi

if [[ -n "$godot_binary" && ! -x "$godot_binary" ]]; then
  echo "ERROR: GODOT_BIN is not an executable file: $godot_binary" >&2
  exit 2
fi

if [[ -z "$godot_binary" ]]; then
  for candidate in godot godot4; do
    if command -v "$candidate" >/dev/null 2>&1; then
      godot_binary="$(command -v "$candidate")"
      break
    fi
  done
fi

if [[ -z "$godot_binary" ]]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: no Godot binary was found and the fallback requires 'curl' to download pinned Godot ${godot_version}." >&2
    exit 2
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: no Godot binary was found and the fallback requires 'python3' to extract pinned Godot ${godot_version}." >&2
    exit 2
  fi

  cache_dir="$project_root/.cache/godot/$godot_version"
  godot_binary="$cache_dir/Godot_v${godot_version}-stable_linux.x86_64"
  archive_path="$cache_dir/Godot_v${godot_version}-stable_linux.x86_64.zip"
  download_url="https://github.com/godotengine/godot-builds/releases/download/${godot_version}-stable/Godot_v${godot_version}-stable_linux.x86_64.zip"

  mkdir -p "$cache_dir"
  if [[ ! -x "$godot_binary" ]]; then
    if [[ ! -f "$archive_path" ]]; then
      echo "Downloading Godot ${godot_version} from the official release archive..." >&2
      partial_archive_path="${archive_path}.part"
      if ! timeout "$download_timeout_seconds" curl --fail --location --silent --show-error \
          --connect-timeout 10 --max-time "$download_timeout_seconds" \
          --output "$partial_archive_path" "$download_url"; then
        echo "ERROR: could not download pinned Godot ${godot_version} within ${download_timeout_seconds}s." >&2
        echo "Set GODOT_BIN to an installed Godot ${godot_version}.stable executable and retry." >&2
        exit 2
      fi
      mv "$partial_archive_path" "$archive_path"
    fi
    if ! timeout 30 python3 - "$archive_path" "$cache_dir" <<'PY'
import sys
import zipfile

archive_path, destination = sys.argv[1:]
with zipfile.ZipFile(archive_path) as archive:
    archive.extractall(destination)
PY
    then
      echo "ERROR: cached Godot ${godot_version} archive is incomplete or invalid: $archive_path" >&2
      echo "Set GODOT_BIN to an installed Godot ${godot_version}.stable executable and retry." >&2
      exit 2
    fi
    chmod +x "$godot_binary"
  fi
fi

if ! version_output="$(timeout 10 "$godot_binary" --version 2>&1)"; then
  echo "ERROR: could not execute the selected Godot binary: $godot_binary" >&2
  exit 2
fi
if [[ "$version_output" != "${godot_version}.stable."* ]]; then
  echo "Expected Godot ${godot_version}.stable, got: ${version_output}" >&2
  exit 2
fi

project_path="$project_root"
if [[ "${godot_binary,,}" == *.exe ]]; then
  if ! command -v wslpath >/dev/null 2>&1; then
    echo "ERROR: Windows Godot binary detected but 'wslpath' is unavailable for project path conversion." >&2
    exit 2
  fi
  project_path="$(wslpath -w "$project_root")"
fi

set +e
test_output="$(timeout "$test_timeout_seconds" "$godot_binary" --headless --path "$project_path" --script res://tests/run_tests.gd -- "$@" 2>&1)"
test_status=$?
set -e
printf '%s\n' "$test_output"
# Consume the full stream so an early match cannot SIGPIPE printf under pipefail.
if printf '%s\n' "$test_output" | grep -E '^ERROR:|SCRIPT ERROR|Parse Error|Compile Error|Failed to load script' >/dev/null; then
  echo "ERROR: Godot reported a runtime, script, or load error." >&2
  test_status=1
fi
if [[ "$test_status" -eq 124 ]]; then
  echo "ERROR: headless Godot tests exceeded ${test_timeout_seconds}s." >&2
fi
exit "$test_status"
