#!/usr/bin/env bash
set -euo pipefail

readonly PRESET_NAME="Windows Desktop"
readonly EXECUTABLE_NAME="ForbiddenTable.exe"
readonly DATA_NAME="ForbiddenTable.pck"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
	cat <<EOF
Usage: scripts/package_windows_release.sh --output-dir <directory>

Build a Windows x64 portable ZIP with pinned Godot ${PINNED_GODOT_VERSION}. Set GODOT_BIN to the
Godot executable when it is not available as `godot` or `godot4` on PATH.
EOF
}

fail() {
	printf 'ERROR: %s\n' "$1" >&2
	exit 1
}

version_file="$PROJECT_ROOT/scripts/GODOT_VERSION"
[[ -r "$version_file" ]] || fail "Pinned Godot version file is missing: $version_file"
IFS= read -r PINNED_GODOT_VERSION < "$version_file"
PINNED_GODOT_VERSION="${PINNED_GODOT_VERSION%$'\r'}"
[[ "$PINNED_GODOT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
	|| fail "Invalid pinned Godot version in $version_file: $PINNED_GODOT_VERSION"
readonly PINNED_GODOT_VERSION

output_dir=""
while (($# > 0)); do
	case "$1" in
		--output-dir)
			(($# >= 2)) || fail "--output-dir requires a directory."
			output_dir="$2"
			shift 2
			;;
		--help|-h)
			usage
			exit 0
			;;
		*)
			fail "Unknown argument: $1"
			;;
	esac
done
[[ -n "$output_dir" ]] || { usage >&2; fail "An output directory is required."; }
command -v timeout >/dev/null 2>&1 || fail "The package build requires the 'timeout' command."
command -v python3 >/dev/null 2>&1 || fail "The package build requires Python 3."

godot_binary="${GODOT_BIN:-}"
if [[ -z "$godot_binary" ]]; then
	for candidate in godot godot4; do
		if command -v "$candidate" >/dev/null 2>&1; then
			godot_binary="$(command -v "$candidate")"
			break
		fi
	done
fi
[[ -n "$godot_binary" && -x "$godot_binary" ]] || fail "Set GODOT_BIN to an executable Godot ${PINNED_GODOT_VERSION}.stable binary."

if ! engine_version="$(timeout 10 "$godot_binary" --version 2>&1)"; then
	fail "Could not run the selected Godot binary: $godot_binary"
fi
if [[ "$engine_version" != "${PINNED_GODOT_VERSION}.stable."* ]]; then
	fail "Expected Godot ${PINNED_GODOT_VERSION}.stable, got: $engine_version"
fi

git_args=(-C "$PROJECT_ROOT" -c "safe.directory=$PROJECT_ROOT")
if ! source_commit="$(git "${git_args[@]}" rev-parse --verify HEAD 2>/dev/null)"; then
	fail "Could not identify the source commit. Run this from a Git checkout."
fi
if ! git_status="$(git "${git_args[@]}" status --porcelain --untracked-files=normal 2>/dev/null)"; then
	fail "Could not inspect the source working tree."
fi
source_dirty=false
if [[ -n "$git_status" ]]; then
	source_dirty=true
	if [[ "${ALLOW_DIRTY_BUILD:-}" != "1" ]]; then
		fail "The source working tree is dirty; release packages require a clean checkout. Set ALLOW_DIRTY_BUILD=1 only for a local smoke package."
	fi
fi

mkdir -p -- "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
temp_dir="$(mktemp -d "$output_dir/.forbidden-table-package.XXXXXXXX")"
published_paths=()
finished=false
cleanup() {
	if [[ "$finished" != true ]]; then
		for path in "${published_paths[@]}"; do
			rm -f -- "$path"
		done
	fi
	rm -rf -- "$temp_dir"
}
trap cleanup EXIT

last_engine_output=""
run_engine() {
	local label="$1"
	shift
	local status=0
	if last_engine_output="$(timeout 600 "$godot_binary" "$@" 2>&1)"; then
		status=0
	else
		status=$?
	fi
	if ((status != 0)); then
		printf 'ERROR: %s failed (exit %s).\n' "$label" "$status" >&2
		printf '%s\n' "$last_engine_output" >&2
		return 1
	fi
	return 0
}

# A fresh checkout may log missing generated translations during its first
# scan; the second headless import must be clean after those resources exist.
run_engine "Initial Godot project import" --headless --editor --path "$PROJECT_ROOT" --import \
	|| fail "Godot could not import the project."
run_engine "Godot import verification" --headless --editor --path "$PROJECT_ROOT" --import \
	|| fail "Godot could not verify the imported project."
if printf '%s\n' "$last_engine_output" | grep -E '^(ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script)' >/dev/null; then
	printf '%s\n' "$last_engine_output" >&2
	fail "Godot reported an import or script error."
fi

run_engine "Release metadata inspection" --headless --path "$PROJECT_ROOT" --script res://scripts/release_metadata.gd \
	|| fail "Godot could not inspect release metadata."
if printf '%s\n' "$last_engine_output" | grep -E '^(ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script)' >/dev/null; then
	printf '%s\n' "$last_engine_output" >&2
	fail "Godot reported an error while inspecting release metadata."
fi
metadata_line="$(printf '%s\n' "$last_engine_output" | sed -n 's/^RELEASE_METADATA_JSON://p' | tail -n 1)"
[[ -n "$metadata_line" ]] || fail "Godot did not emit the release metadata record."

metadata_file="$temp_dir/engine-metadata.json"
printf '%s\n' "$metadata_line" > "$metadata_file"
metadata_values="$temp_dir/metadata-values.json"
python3 - "$metadata_file" "$metadata_values" <<'PY'
import json
import re
import sys

source, destination = sys.argv[1:]
with open(source, encoding="utf-8") as stream:
    metadata = json.load(stream)
required = {
    "application_version",
    "content_version",
    "game_version",
    "save_schema_versions",
    "replay_schema_version",
    "replay_game_version",
}
if required - metadata.keys():
    raise SystemExit("Release metadata is missing required identity fields.")
if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", str(metadata["application_version"])):
    raise SystemExit("Project application version is not a safe release version.")
if not metadata["content_version"] or not metadata["game_version"] or not metadata["replay_game_version"]:
    raise SystemExit("Release metadata has an empty content or game identity.")
if not isinstance(metadata["save_schema_versions"], dict) or not metadata["save_schema_versions"]:
    raise SystemExit("Release metadata has no save schema identities.")
if not isinstance(metadata["replay_schema_version"], int):
    raise SystemExit("Release metadata has no replay schema identity.")
with open(destination, "w", encoding="utf-8", newline="\n") as stream:
    json.dump(metadata, stream, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    stream.write("\n")
PY
project_version="$(python3 - "$metadata_values" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    print(json.load(stream)["application_version"])
PY
)"
archive_name="forbidden-table-${project_version}-windows-x64.zip"
archive_path="$output_dir/$archive_name"
checksum_path="$archive_path.sha256"
manifest_path="$archive_path.build.json"
for final_path in "$archive_path" "$checksum_path" "$manifest_path"; do
	[[ ! -e "$final_path" ]] || fail "Refusing to overwrite existing build output: $final_path"
done

export_dir="$temp_dir/export"
mkdir -p -- "$export_dir"
run_engine "Windows release export" --headless --path "$PROJECT_ROOT" --export-release "$PRESET_NAME" "$export_dir/$EXECUTABLE_NAME" \
	|| fail "Windows release export failed. Install the Godot ${PINNED_GODOT_VERSION} Windows x64 export templates and retry."
[[ -s "$export_dir/$EXECUTABLE_NAME" ]] \
	|| fail "Godot did not produce the expected executable: $EXECUTABLE_NAME"
[[ -s "$export_dir/$DATA_NAME" ]] \
	|| fail "Godot did not produce the expected data pack: $DATA_NAME"
python3 - "$export_dir/$DATA_NAME" <<'PY'
from pathlib import Path
import struct
import sys

pack = Path(sys.argv[1]).read_bytes()
header_size = 112
if len(pack) < header_size:
    raise SystemExit("ERROR: Windows PCK has a truncated header.")
magic, format_version, _, _, _, pack_flags = struct.unpack_from("<6I", pack, 0)
file_base, directory_offset = struct.unpack_from("<QQ", pack, 24)
if magic != 0x43504447 or format_version != 4:
    raise SystemExit("ERROR: Windows PCK has an unsupported header format.")
if pack_flags & 0x1:
    raise SystemExit("ERROR: Windows PCK has an encrypted directory that cannot be inspected.")
if file_base < header_size or file_base > len(pack) or directory_offset < file_base or directory_offset + 4 > len(pack):
    raise SystemExit("ERROR: Windows PCK has invalid directory offsets.")
file_count = struct.unpack_from("<I", pack, directory_offset)[0]
cursor = directory_offset + 4
if file_count > (len(pack) - cursor) // 40:
    raise SystemExit("ERROR: Windows PCK has an invalid file count.")
packaged_resources = {}
for _ in range(file_count):
    if cursor + 4 > len(pack):
        raise SystemExit("ERROR: Windows PCK has a truncated file index.")
    path_length = struct.unpack_from("<I", pack, cursor)[0]
    cursor += 4
    if path_length > len(pack) - cursor:
        raise SystemExit("ERROR: Windows PCK has an invalid file path length.")
    try:
        path = pack[cursor:cursor + path_length].rstrip(b"\0").decode("utf-8")
    except UnicodeDecodeError as error:
        raise SystemExit(f"ERROR: Windows PCK has an invalid file path: {error}")
    cursor += (path_length + 3) & ~3
    if cursor + 36 > len(pack):
        raise SystemExit("ERROR: Windows PCK has a truncated file entry.")
    data_offset, data_size = struct.unpack_from("<QQ", pack, cursor)
    if file_base + data_offset > directory_offset or data_size > directory_offset - (file_base + data_offset):
        raise SystemExit(f"ERROR: Windows PCK has an invalid payload range for {path}.")
    cursor += 36  # Data offset, size, MD5, and flags.
    packaged_resources[path] = data_size

development_paths = sorted(
    path for path in packaged_resources
    if path.startswith(("tests/", "scripts/", ".scratch/", ".cache/", "dist/", "docs/", "forbidden_table_spec/", ".codex-worktrees/", "graphify-out/", ".github/"))
)
if development_paths:
    print("ERROR: Windows PCK contains development-only resources or local artifacts:", file=sys.stderr)
    for path in development_paths[:20]:
        print("  " + path, file=sys.stderr)
    raise SystemExit(1)

required_runtime_paths = {
    "project.binary",
    "scenes/run/run_scene.tscn.remap",
    "scenes/run/run_scene.gd.remap",
    "scenes/run/run_scene.gdc",
}
missing_runtime_paths = sorted(
    path for path in required_runtime_paths
    if packaged_resources.get(path, 0) <= 0
)
main_scene_exports = [
    path for path, size in packaged_resources.items()
    if path.startswith(".godot/exported/") and path.endswith("-run_scene.scn") and size > 0
]
if missing_runtime_paths or not main_scene_exports:
    missing = missing_runtime_paths
    if not main_scene_exports:
        missing.append("compiled main scene")
    raise SystemExit("ERROR: Windows PCK is missing required main scene resources: " + ", ".join(missing))
PY

python3 - \
	"$PROJECT_ROOT/docs/release/WINDOWS_PACKAGE_README.txt" \
	"$PROJECT_ROOT/docs/release/WINDOWS_RELEASE_NOTES.txt" \
	"$export_dir/README.txt" \
	"$export_dir/RELEASE_NOTES.txt" \
	"$project_version" <<'PY'
from pathlib import Path
import re
import sys

readme_template, notes_template, readme_output, notes_output, version = sys.argv[1:]
placeholder = "@APPLICATION_VERSION@"
for template_path, output_path in (
    (readme_template, readme_output),
    (notes_template, notes_output),
):
    source = Path(template_path).read_text(encoding="utf-8")
    if source.count(placeholder) != 1:
        raise SystemExit(f"Release material must contain one {placeholder} token: {template_path}")
    rendered = source.replace(placeholder, version)
    if re.search(r"@[A-Z0-9_]+@", rendered):
        raise SystemExit(f"Release material has an unresolved placeholder: {template_path}")
    with open(output_path, "w", encoding="utf-8", newline="\n") as stream:
        stream.write(rendered)
PY

python3 - "$PROJECT_ROOT" "$export_dir" <<'PY'
from pathlib import Path
import shutil
import sys
root, export = map(Path, sys.argv[1:])
materials = {
    "THIRD_PARTY_NOTICES.md": "docs/release/THIRD_PARTY_NOTICES.md",
    "licenses/Godot-LICENSE.txt": "docs/release/licenses/Godot-LICENSE.txt",
    "licenses/Godot-COPYRIGHT.txt": "docs/release/licenses/Godot-COPYRIGHT.txt",
    "licenses/Noto-OFL.txt": "assets/ui/fonts/OFL.txt",
    "licenses/NotoSansSC-OFL.txt": "assets/ui/fonts/OFL-Sans.txt",
    "licenses/NotoSerifSC-OFL.txt": "assets/ui/fonts/OFL-Serif.txt",
    "licenses/Mahjong-tiles-LICENSE.txt": "assets/ui/tiles/chinese-tiles/LICENSE",
    "licenses/Mahjong-tiles-ATTRIBUTION.md": "assets/ui/tiles/chinese-tiles/README.md",
}
if (root / "LICENSE").is_file():
    materials["LICENSE.txt"] = "LICENSE"
for name, source in materials.items():
    path = root / source
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"Missing required release notice: {source}")
    destination = export / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, destination)
PY

archive_temp="$temp_dir/$archive_name"
python3 - "$export_dir" "$archive_temp" <<'PY'
from pathlib import Path
import sys
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
with ZipFile(destination, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
    for name in sorted(path.relative_to(source).as_posix() for path in source.rglob("*") if path.is_file()):
        path = source / name
        info = ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
        info.create_system = 3
        info.external_attr = ((0o100755 if name.endswith(".exe") else 0o100644) << 16)
        info.compress_type = ZIP_DEFLATED
        archive.writestr(info, path.read_bytes(), compress_type=ZIP_DEFLATED, compresslevel=9)
PY

artifact_sha256="$(python3 - "$archive_temp" <<'PY'
import hashlib
import sys
from pathlib import Path
print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
source_dirty_json="$source_dirty"
python3 - "$metadata_values" "$temp_dir/build.json" "$engine_version" "$source_commit" "$source_dirty_json" "$archive_name" "$artifact_sha256" <<'PY'
import json
import sys

metadata_path, output_path, engine_version, source_commit, source_dirty, archive_name, digest = sys.argv[1:]
with open(metadata_path, encoding="utf-8") as stream:
    manifest = json.load(stream)
manifest.update({
    "artifact": archive_name,
    "artifact_sha256": digest,
    "engine_version": engine_version,
    "platform": "windows-x86_64",
    "source_commit": source_commit,
    "source_dirty": source_dirty == "true",
})
with open(output_path, "w", encoding="utf-8", newline="\n") as stream:
    json.dump(manifest, stream, ensure_ascii=False, sort_keys=True, indent=2)
    stream.write("\n")
PY
printf '%s  %s\n' "$artifact_sha256" "$archive_name" > "$temp_dir/$archive_name.sha256"

mv -- "$archive_temp" "$archive_path"
published_paths+=("$archive_path")
mv -- "$temp_dir/$archive_name.sha256" "$checksum_path"
published_paths+=("$checksum_path")
mv -- "$temp_dir/build.json" "$manifest_path"
published_paths+=("$manifest_path")
finished=true
printf 'PACKAGE=%s\nSHA256=%s\nMANIFEST=%s\n' "$archive_path" "$artifact_sha256" "$manifest_path"
