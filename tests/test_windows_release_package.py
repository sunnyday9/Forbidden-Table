import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PACKAGE_SCRIPT = ROOT / "scripts" / "package_windows_release.sh"
EXPECTED_NAME = "forbidden-table-1.0.0-rc.1-windows-x64.zip"
ENGINE_METADATA = {
    "application_version": "1.0.0-rc.1",
    "content_version": "content.bundle.v1.alpha.act_two@v5+alpha.scale@v12+phase2@v4",
    "game_version": "game.phase2.v1",
    "save_schema_versions": {"suspend_snapshot": 1, "meta_progress": 2},
    "replay_schema_version": 1,
}


class WindowsReleasePackageTest(unittest.TestCase):
    def setUp(self):
        self.temp_root = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_root.name)
        self.engine = self.root / "godot-stub"
        self.engine.write_text(
            "#!/usr/bin/env bash\n"
            "set -euo pipefail\n"
            "if [[ \"$1\" == \"--version\" ]]; then\n"
            "  echo \"${GODOT_TEST_VERSION:-4.7.2.stable.official.test}\"\n"
            "  exit 0\n"
            "fi\n"
            "if [[ \" $* \" == *\"res://scripts/release_metadata.gd\"* ]]; then\n"
            f"  echo 'RELEASE_METADATA_JSON:{json.dumps(ENGINE_METADATA, sort_keys=True)}'\n"
            "  exit 0\n"
            "fi\n"
            "arguments=(\"$@\")\n"
            "for ((index = 0; index < ${#arguments[@]}; index++)); do\n"
            "  if [[ \"${arguments[$index]}\" == \"--export-release\" ]]; then\n"
            "    preset=\"${arguments[$((index + 1))]:-}\"\n"
            "    output=\"${arguments[$((index + 2))]:-}\"\n"
            "    [[ \"$preset\" == \"Windows Desktop\" ]] || exit 31\n"
            "    [[ \"$output\" == *.exe ]] || exit 32\n"
            "    [[ \"${GODOT_EXPORT_STATUS:-0}\" == 0 ]] || exit \"$GODOT_EXPORT_STATUS\"\n"
            "    if [[ \"${GODOT_OMIT_EXPORT:-0}\" != 1 ]]; then\n"
            "      mkdir -p \"$(dirname \"$output\")\"\n"
            "      printf 'portable executable fixture\\n' > \"$output\"\n"
            "      python3 - \"${output%.exe}.pck\" \"${GODOT_PCK_CONTENT:-}\" <<'PY'\n"
            "import hashlib, os, struct, sys\n"
            "from pathlib import Path\n"
            "pck_path = Path(sys.argv[1])\n"
            "paths = ['project.binary', 'scenes/run/run_scene.tscn.remap', 'scenes/run/run_scene.gd.remap', 'scenes/run/run_scene.gdc', '.godot/exported/test-run_scene.scn']\n"
            "if os.environ.get('GODOT_PCK_OMIT_MAIN') == '1': paths.remove('scenes/run/run_scene.tscn.remap')\n"
            "paths.extend(name for name in sys.argv[2].split('|') if name)\n"
            "body = os.environ.get('GODOT_PCK_BODY', '').encode()\n"
            "payloads = [body if name.endswith('.md') else name.encode() for name in paths]\n"
            "file_base = 112\n"
            "data = b''.join(payloads)\n"
            "directory_offset = file_base + len(data)\n"
            "header = struct.pack('<6IQQ', 0x43504447, 4, 4, 7, 2, 2, file_base, directory_offset) + bytes(72)\n"
            "directory = bytearray(struct.pack('<I', len(paths)))\n"
            "relative_offset = 0\n"
            "for name, payload in zip(paths, payloads):\n"
            "    encoded = name.encode()\n"
            "    padded_length = (len(encoded) + 3) & ~3\n"
            "    directory += struct.pack('<I', padded_length) + encoded + bytes(padded_length - len(encoded))\n"
            "    directory += struct.pack('<QQ', relative_offset, len(payload)) + hashlib.md5(payload).digest() + struct.pack('<I', 0)\n"
            "    relative_offset += len(payload)\n"
            "pck_path.write_bytes(header + data + directory)\n"
            "PY\n"
            "      if [[ \"${GODOT_PCK_CORRUPT:-0}\" == 1 ]]; then printf 'not a PCK' > \"${output%.exe}.pck\"; fi\n"
            "    fi\n"
            "    exit 0\n"
            "  fi\n"
            "done\n"
            "exit 0\n",
            encoding="utf-8",
        )
        self.engine.chmod(0o755)

    def tearDown(self):
        self.temp_root.cleanup()

    def _run_package(self, output_dir, *, git_status="", **extra_env):
        environment = dict(os.environ)
        environment.update({"GODOT_BIN": str(self.engine)})
        environment.update(self._fake_git_environment(git_status))
        environment.update(extra_env)
        return subprocess.run(
            ["bash", str(PACKAGE_SCRIPT), "--output-dir", str(output_dir)],
            cwd=ROOT,
            env=environment,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def _fake_git_environment(self, status):
        fake_bin = self.root / "fake-bin"
        fake_bin.mkdir(exist_ok=True)
        fake_git = fake_bin / "git"
        fake_git.write_text(
            "#!/usr/bin/env bash\n"
            "case \" $* \" in\n"
            "  *rev-parse*) echo 0123456789abcdef0123456789abcdef01234567 ;;\n"
            "  *status*) printf '%s\\n' \"${FAKE_GIT_STATUS}\" ;;\n"
            "  *) exit 3 ;;\n"
            "esac\n",
            encoding="utf-8",
        )
        fake_git.chmod(0o755)
        return {
            "PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}",
            "FAKE_GIT_STATUS": status,
        }

    def _artifact(self, output_dir):
        return Path(output_dir) / EXPECTED_NAME

    def test_package_contains_only_launchable_runtime_files_and_build_identity(self):
        output_dir = self.root / "success"

        result = self._run_package(output_dir)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        archive = self._artifact(output_dir)
        self.assertTrue(archive.is_file())
        self.assertEqual(
            {path.name for path in output_dir.iterdir()},
            {EXPECTED_NAME, f"{EXPECTED_NAME}.sha256", f"{EXPECTED_NAME}.build.json"},
        )
        with zipfile.ZipFile(archive) as package:
            self.assertEqual(
                set(package.namelist()),
                {"ForbiddenTable.exe", "ForbiddenTable.pck", "README.txt"},
            )
            self.assertIsNone(package.testzip())
            readme = package.read("README.txt").decode("utf-8")
            self.assertIn("Extract", readme)
            self.assertIn("ForbiddenTable.exe", readme)

        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        checksum_path = Path(f"{archive}.sha256")
        self.assertEqual(checksum_path.read_text(encoding="utf-8").split()[0], digest)
        self.assertIn(archive.name, checksum_path.read_text(encoding="utf-8"))

        manifest_path = Path(f"{archive}.build.json")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(manifest["application_version"], "1.0.0-rc.1")
        self.assertEqual(manifest["engine_version"], "4.7.2.stable.official.test")
        self.assertEqual(manifest["platform"], "windows-x86_64")
        self.assertFalse(manifest["source_dirty"])
        for key, value in ENGINE_METADATA.items():
            self.assertEqual(manifest[key], value)
        self.assertTrue(manifest["source_commit"])
        self.assertEqual(manifest["artifact_sha256"], digest)

    def test_same_source_export_produces_stable_zip_and_checksum(self):
        first_dir = self.root / "first"
        second_dir = self.root / "second"

        first = self._run_package(first_dir)
        second = self._run_package(second_dir)

        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        first_archive = self._artifact(first_dir)
        second_archive = self._artifact(second_dir)
        self.assertEqual(first_archive.read_bytes(), second_archive.read_bytes())
        self.assertEqual(
            Path(f"{first_archive}.sha256").read_text(encoding="utf-8"),
            Path(f"{second_archive}.sha256").read_text(encoding="utf-8"),
        )

    def test_existing_package_files_are_never_overwritten(self):
        output_dir = self.root / "no-overwrite"
        initial = self._run_package(output_dir)
        archive = self._artifact(output_dir)
        original_bytes = archive.read_bytes()

        result = self._run_package(output_dir)

        self.assertEqual(initial.returncode, 0, initial.stdout + initial.stderr)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing to overwrite existing build output", result.stderr)
        self.assertEqual(archive.read_bytes(), original_bytes)

    def test_wrong_engine_version_fails_without_publishing_partial_artifacts(self):
        output_dir = self.root / "wrong-engine"

        result = self._run_package(output_dir, GODOT_TEST_VERSION="4.7.1.stable.official.test")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Expected Godot 4.7.2.stable", result.stderr)
        self.assertFalse(output_dir.exists() and any(output_dir.iterdir()))

    def test_dirty_checkout_requires_an_explicit_local_smoke_override(self):
        output_dir = self.root / "dirty-checkout"
        result = self._run_package(output_dir, git_status="?? synthetic-uncommitted-file")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("working tree is dirty", result.stderr)
        self.assertFalse(output_dir.exists() and any(output_dir.iterdir()))

        smoke_dir = self.root / "dirty-smoke-override"
        smoke = self._run_package(
            smoke_dir,
            git_status="?? synthetic-uncommitted-file",
            ALLOW_DIRTY_BUILD="1",
        )
        self.assertEqual(smoke.returncode, 0, smoke.stdout + smoke.stderr)
        smoke_manifest = json.loads(
            Path(f"{self._artifact(smoke_dir)}.build.json").read_text(encoding="utf-8")
        )
        self.assertTrue(smoke_manifest["source_dirty"])

    def test_export_failure_fails_without_publishing_partial_artifacts(self):
        output_dir = self.root / "failed-export"

        result = self._run_package(output_dir, GODOT_EXPORT_STATUS="9")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Windows release export failed", result.stderr)
        self.assertFalse(output_dir.exists() and any(output_dir.iterdir()))

    def test_successful_engine_exit_without_exported_executable_is_rejected(self):
        output_dir = self.root / "missing-export"

        result = self._run_package(output_dir, GODOT_OMIT_EXPORT="1")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not produce the expected executable", result.stderr)
        self.assertFalse(output_dir.exists() and any(output_dir.iterdir()))

    def test_development_scripts_in_pck_are_rejected(self):
        output_dir = self.root / "development-script-in-pck"

        result = self._run_package(output_dir, GODOT_PCK_CONTENT="tests/leaked_test.gdc")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("development-only resources", result.stderr)
        self.assertIn("tests/leaked_test.gdc", result.stderr)
        self.assertFalse(output_dir.exists() and any(output_dir.iterdir()))

    def test_test_fixture_data_in_pck_is_rejected(self):
        output_dir = self.root / "test-fixture-data-in-pck"

        result = self._run_package(
            output_dir,
            GODOT_PCK_CONTENT="tests/fixtures/leaked_fixture.json",
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("tests/fixtures/leaked_fixture.json", result.stderr)
        self.assertFalse(output_dir.exists() and any(output_dir.iterdir()))

    def test_malformed_pck_fails_without_publishing_partial_artifacts(self):
        output_dir = self.root / "malformed-pck"

        result = self._run_package(output_dir, GODOT_PCK_CORRUPT="1")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("PCK has a truncated header", result.stderr)
        self.assertFalse(output_dir.exists() and any(output_dir.iterdir()))

    def test_missing_main_scene_fails_without_publishing_partial_artifacts(self):
        output_dir = self.root / "missing-main-scene"

        result = self._run_package(output_dir, GODOT_PCK_OMIT_MAIN="1")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("main scene resource", result.stderr)
        self.assertFalse(output_dir.exists() and any(output_dir.iterdir()))

    def test_documentation_mentions_of_script_paths_do_not_look_like_pck_files(self):
        output_dir = self.root / "documentation-script-reference"

        result = self._run_package(
            output_dir,
            GODOT_PCK_CONTENT="forbidden_table_spec/evidence.md",
            GODOT_PCK_BODY="This archived report refers to tests/leaked_test.gd.",
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self._artifact(output_dir).is_file())

    def test_script_remap_metadata_is_not_mistaken_for_a_packaged_script(self):
        output_dir = self.root / "script-remap-metadata"

        result = self._run_package(
            output_dir,
            GODOT_PCK_CONTENT="scenes/run/phase2_v1_suspend_snapshot.gd.remap",
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self._artifact(output_dir).is_file())

    def test_export_preset_excludes_every_test_and_build_file(self):
        preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        match = re.search(r'^export_files=PackedStringArray\(([^\n]*)\)$', preset, re.MULTILINE)
        self.assertIsNotNone(match, "Windows export preset must declare exact excluded files")
        self.assertIn('application/file_version="1.0.0.0"', preset)
        self.assertIn('application/product_version="1.0.0.0"', preset)
        excluded = set(re.findall(r'"(res://[^"]+)"', match.group(1)))
        expected = {
            "res://" + path.relative_to(ROOT).as_posix()
            for directory in (ROOT / "scripts", ROOT / "tests")
            for path in directory.rglob("*")
            if path.is_file() and (path.suffix == ".gd" or (directory.name == "tests" and path.suffix == ".json"))
        }
        self.assertEqual(excluded, expected)


if __name__ == "__main__":
    unittest.main()
