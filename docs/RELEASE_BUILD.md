# Windows release package

The Stage 5 candidate is a portable Windows x64 ZIP. Use Godot **4.7.2 stable** and its matching Windows x64 export templates from the [official Godot 4.7.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable). The project is imported headlessly, so the build does not need an open editor or a developer-specific executable path.

## Build prerequisites

- A clean Git checkout of the candidate commit.
- Godot 4.7.2 stable and its matching export templates installed for the current user.
- Bash, Python 3, and `timeout` available in the build shell.

Set `GODOT_BIN` to the Godot executable if it is not available as `godot` or `godot4` on `PATH`. Then run:

```bash
GODOT_BIN="/path/to/Godot_v4.7.2-stable" ./scripts/test.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_windows_release_package.py'
GODOT_BIN="/path/to/Godot_v4.7.2-stable" ./scripts/package_windows_release.sh --output-dir dist
```

The package command checks the exact stable engine version and a clean source tree, imports project resources twice in headless mode, reads the live content/save/replay identities from the game catalogs, and exports the `Windows Desktop` x86_64 preset. `ALLOW_DIRTY_BUILD=1` is available only for local smoke packages; the sidecar records `source_dirty: true`, so that artifact is not RC evidence.

## Outputs

The output directory receives three files:

- `forbidden-table-<version>-windows-x64.zip`, containing `ForbiddenTable.exe`, its `.pck` data file, and concise launch instructions.
- The ZIP's `.sha256` sidecar, in `sha256sum` format.
- The ZIP's `.build.json` sidecar, recording the source commit, source cleanliness, exact engine build, application/content/game versions, save/replay schema versions, target platform, and artifact hash.

The ZIP entries use normalized timestamps and a stable order to make repeated exports from the same source and engine reproducible. The script refuses to overwrite existing outputs. It does not publish a tag or GitHub Release.

For the exact supported release order and public gates, see [the Stage 5 release spec](../forbidden_table_spec/STAGE_5_RELEASE_SPEC.md).
