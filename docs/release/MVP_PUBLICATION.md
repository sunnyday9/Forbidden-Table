# MVP publication decision

## Accepted scope

Publish **1.0.0-mvp.1** as an experimental Windows x64 prerelease, make the repository public, and merge the validated MVP changes. This is not the stable 1.0 compatibility/balance milestone in issues #105–107.

The maintainer reported completing human two-Act simulation/testing and explicitly requested continuing publication. The maintainer selected **MIT** for the game source. The source license is recorded in the root LICENSE; bundled dependencies/assets retain their own notices.

Human validation is owner-reported. The report does not identify separate Windows 10 and Windows 11 coverage, physical input devices, a monitor, seed list, or artifact hash. No additional coverage is inferred. The game source is unchanged from the validated candidate `73b3256b4b10388751af1af65192631db6feffef`; publication changes add licensing and update release documentation.

## Automated evidence and limitations

- The candidate passed 21 Python tests, bilingual localization checks (1324 entries per locale), the functional MVP profile, all 26 UI regression modules, isolated PCK gameplay smoke, and native executable headless startup.
- GitHub CI passed functional validation, Windows packaging, and an extracted PCK probe: https://github.com/sunnyday9/Forbidden-Table/actions/runs/37818892027.
- The diagnostic simulation lane remains red with 23 assertions: 17 progression/reward expectations, four fixed benchmark expectations, and two Windows corpus/resume checks. The full 1000-seed stable gate was not run. Owner playtesting does not turn these automated failures into passes.
- Pre-1.0 compatibility has no general guarantee. Older saved battles preserve their current rules until the next battle; some older rule-version replays are unavailable. Hand display order resets on restart.

## Public-source review

Reviewed all 8 remote ref entries and 1505 unique historical text blobs, 108 issues/PRs, 127 issue comments, Actions logs/artifact inventory and draft release materials. Credential-pattern screening found no high-confidence matches. This is publication hygiene review, not an exhaustive security certification.

Tracked release/design evidence concerns this game; asset attribution and bundled licenses are retained. Godot MIT/dependency notices, Noto OFL licenses, and mahjong tile licenses/attribution travel with the Windows package. Public launch/support instructions describe the accepted MVP scope. Local saves, settings, worktree backups and private operational evidence under `.scratch/` remain ignored by Git and excluded from the PCK.

The maintainer's request supplies the MVP publication go decision. Stable release gate issues remain open until their distinct criteria are satisfied; this publication does not close them as completed.
