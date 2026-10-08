# MVP release workflow

1. Preserve existing worktree changes, detached commits, and player saves. Consolidate the candidate on a `codex/` branch; do not erase unrelated work.
2. Run localization, Python packaging/provenance tests, and `scripts/test_mvp.sh`. This functional profile covers the domain, save/replay, campaign presentation, bilingual UI, accessibility layout, and Guided Sample. It excludes `alpha-simulation`, `alpha-simulation-coverage`, `alpha-fixed-run-benchmark`, and `alpha-gate-corpus-resume`; run these through the separate full validation workflow. Do not describe a functional pass as a full-suite or balance pass.
3. Commit all candidate source and build from a clean checkout with the pinned editor and matching templates. Preserve the ZIP, SHA-256 sidecar, and build manifest. Packages include third-party notices and reject development resources in the PCK.
4. Extract the ZIP into an isolated directory. Run the packaged executable startup check and external `scripts/release_smoke_probe.gd` with the PCK and a fresh test profile. Record the exact source commit and artifact hash. These checks are automated evidence, not human playtesting or physical controller coverage.
5. Push the branch and open a PR. The MVP workflow validates functional behavior and builds a Windows artifact. The manually triggered full validation workflow reports broader results; neither workflow publishes releases or changes repository visibility.
6. Create a **draft prerelease** at the exact tested commit. Upload the ZIP and both sidecars, download them again, and compare hashes. List known limitations in release notes.
7. Before public publication, resolve the source license, audit public source/history and asset rights, and obtain the maintainer's visibility/publication go/no-go in issue #106. Stable 1.0 additionally requires the corpus, supported-platform human validation, and findings disposition in #105–107. MVP preparation does not close those issues.

Use a new prerelease version for changes to a published candidate. Never silently replace an already published ZIP with a different build.
