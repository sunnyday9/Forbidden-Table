import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]

def shell_path(path):
    if os.name != "nt":
        return str(path)
    return subprocess.check_output(["cygpath", "-u", str(path)], text=True, encoding="utf-8").strip()


class TestWrapperTest(unittest.TestCase):
    def _run_engine_output(self, output: str, engine_status: int = 0):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            (fixture / "output.txt").write_text(output, encoding="utf-8")
            engine = fixture / "engine"
            engine.write_text(
                '#!/usr/bin/env bash\n'
                'if [[ "$1" == "--version" ]]; then\n'
                '  echo "4.7.2.stable.official.test"\n'
                '  exit 0\n'
                'fi\n'
                'cat "${GODOT_TEST_OUTPUT}"\n'
                'exit "${GODOT_TEST_STATUS}"\n',
                encoding="utf-8",
            )
            engine.chmod(0o755)
            return subprocess.run(
                [shutil.which("bash") or "bash", shell_path(ROOT / "scripts" / "test.sh")],
                env=dict(
                    os.environ,
                    GODOT_BIN=shell_path(engine),
                    GODOT_TEST_OUTPUT=shell_path(fixture / "output.txt"),
                    GODOT_TEST_STATUS=str(engine_status),
                ),
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=20,
            )

    def test_runtime_error_at_start_of_long_log_fails_even_if_engine_exits_zero(self):
        output = "ERROR: runtime fixture failure\n" + "ordinary engine output\n" * 100000

        result = self._run_engine_output(output)

        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(result.stdout, output)

    def test_long_clean_log_succeeds(self):
        result = self._run_engine_output("ordinary engine output\n" * 100000)

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_nonzero_engine_status_is_preserved(self):
        result = self._run_engine_output("ordinary engine output\n", engine_status=7)

        self.assertEqual(result.returncode, 7, result.stderr)

    def test_script_and_load_diagnostics_fail_even_if_engine_exits_zero(self):
        for diagnostic in (
            "SCRIPT ERROR: fixture failure",
            "Parse Error: fixture failure",
            "Compile Error: fixture failure",
            "Failed to load script: fixture failure",
        ):
            with self.subTest(diagnostic=diagnostic):
                result = self._run_engine_output(diagnostic + "\n")

                self.assertEqual(result.returncode, 1, result.stderr)


if __name__ == "__main__":
    unittest.main()
