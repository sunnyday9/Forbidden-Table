"""Install the pinned Linux editor and optional Windows templates for CI."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import urllib.request
from zipfile import ZipFile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--templates", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    version = (root / "scripts/GODOT_VERSION").read_text().strip()
    cache = root / ".cache/godot" / version
    cache.mkdir(parents=True, exist_ok=True)
    base = f"https://github.com/godotengine/godot-builds/releases/download/{version}-stable/"
    with urllib.request.urlopen(base + "SHA512-SUMS.txt", timeout=120) as response:
        sums = dict((line.split()[-1].lstrip("*"), line.split()[0])
                    for line in response.read().decode().splitlines() if line.strip())

    def download(name):
        path = cache / name
        if not path.exists():
            temporary = path.with_suffix(path.suffix + ".part")
            with urllib.request.urlopen(base + name, timeout=120) as response, temporary.open("wb") as output:
                shutil.copyfileobj(response, output)
            temporary.replace(path)
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha512").hexdigest()
        if digest != sums.get(name):
            raise SystemExit(f"Official SHA-512 mismatch: {name}")
        return path

    executable = f"Godot_v{version}-stable_linux.x86_64"
    with ZipFile(download(executable + ".zip")) as archive:
        (cache / executable).write_bytes(archive.read(executable))
    (cache / executable).chmod(0o755)
    if args.templates:
        templates = Path.home() / ".local/share/godot/export_templates" / f"{version}.stable"
        templates.mkdir(parents=True, exist_ok=True)
        with ZipFile(download(f"Godot_v{version}-stable_export_templates.tpz")) as archive:
            for name in ("version.txt", "windows_release_x86_64.exe", "windows_debug_x86_64.exe"):
                (templates / name).write_bytes(archive.read("templates/" + name))
    if os.environ.get("GITHUB_ENV"):
        with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as stream:
            stream.write(f"GODOT_BIN={cache / executable}\n")
    print(cache / executable)


if __name__ == "__main__":
    main()
