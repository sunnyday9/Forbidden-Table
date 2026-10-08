# Forbidden Table

A single-player mahjong roguelite built with Godot. Build a Hand, settle patterns, and choose rewards and routes through two Acts.

The current candidate is **1.0.0-mvp.1**, an experimental Windows x64 prerelease. Download the portable ZIP from [the MVP release](https://github.com/sunnyday9/Forbidden-Table/releases/tag/v1.0.0-mvp.1).

## Play

Extract the entire ZIP and run `ForbiddenTable.exe` beside `ForbiddenTable.pck`. Windows 10/11 x64 is the intended target. Open Settings for English or Simplified Chinese, UI scale, and reduced motion. Guided Sample introduces the basic loop.

- Sort Hand groups tiles by suit and rank. Drag tiles, or use the move controls, to arrange them yourself.
- Discard displays its tile count.
- Play 1–3 Hand tiles during each turn before End Turn. Three played tiles forming a sequence or triplet earn +3 Gold. Play moves tiles to Discard without drawing replacements.

Saves and settings are in `%APPDATA%\Godot\app_userdata\Forbidden Table`. Back up that folder before trying a prerelease. Older saved battles retain their current rules; newly started battles use the new Hand-play rule. Hand display order resets on restart. Some older replays are unavailable after rule changes. Pre-1.0 compatibility is not a general promise.

## Development

Use the pinned Godot version in `scripts/GODOT_VERSION` (currently 4.7.2) and Python 3.12. Install matching Windows x64 export templates for packaging. Shell tools require Bash and GNU timeout.

```bash
python3 scripts/validate_localization.py
python3 -m unittest discover -s tests -p 'test_*.py'
bash scripts/test_mvp.sh
bash scripts/test.sh
bash scripts/package_windows_release.sh --output-dir dist
```

Set `GODOT_BIN` to an installed executable. The test wrapper can download the pinned Linux editor. Release packages require a clean Git checkout and include a checksum and source/build manifest. See [the release workflow](docs/release/MVP_RELEASE_WORKFLOW.md) for checks and evidence boundaries.

The MVP functional profile excludes the four simulation/benchmark/corpus suites, which remain in the full validation lane. The maintainer reports completing human two-Act validation. Fixed-seed progression failures and platform/device-specific coverage remain open; this candidate is not the stable 1.0 release described by issues #105–107.

Report problems in [GitHub Issues](https://github.com/sunnyday9/Forbidden-Table/issues), with version, language, seed, and steps. Domain terms live in [CONTEXT.md](CONTEXT.md). Local builds, caches, and evidence are ignored by Git.

## Licensing

Original game source is licensed under [MIT](LICENSE). Third-party dependencies and assets retain their own licenses. Dependency and asset notices are in [THIRD_PARTY_NOTICES.md](docs/release/THIRD_PARTY_NOTICES.md) and travel with the Windows package.
