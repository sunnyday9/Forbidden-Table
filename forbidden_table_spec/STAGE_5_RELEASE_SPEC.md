# Stage 5 — 1.0 Release Candidate and Public Release

**Status:** Scope aligned for planning on 2026-10-04. Implementation, public repository visibility, and release publication have not been authorized by this document.

**Decision owner:** Project maintainer.

**Authority:** This document records the accepted Stage 5 decisions and defines candidate, private-RC, and public-release gates. The existing Stage 4 Beta PASS is evidence for its own gate only; it is not release authorization.

## 1. Release target and boundaries

Stage 5 prepares and verifies a frozen 1.0 candidate, validates that candidate privately, then uses a separate maintainer go/no-go before public publication.

| Area | Accepted Stage 5 scope |
|---|---|
| Product target | Public desktop 1.0 |
| Distribution | GitHub Release attached to this repository |
| Supported platforms | Windows 10 and Windows 11, x64 |
| Release candidate | Private, owner-only RC; no outside testers are planned |
| Public gate | Separate go/no-go after private RC validation |
| Save/replay compatibility | Begin at public 1.0.0 and carry supported formats through 1.0.x patch updates; later minor versions are undecided |
| Performance | No numeric performance target |
| Campaign | The existing continuous two-Act Run remains unchanged |
| Onboarding | One optional, short, isolated Guided Sample; it is not a new Act or campaign Run |

The project glossary defines a **Run** as one attempt through the Act sequence and an **Act** as a chapter within that Run. The Guided Sample is a separate, bounded teaching scenario; use that term in domain and test names. A player-facing entry may say “Sample Run.”

Stage 4’s rule against unnecessary new systems remains in force. The Guided Sample is the one explicit, owner-approved onboarding addition for this release. Do not add other major systems under this scope.

### Out of scope

- Steam Deck, macOS, Linux, and other platform release claims.
- Numeric frame-rate, latency, or performance thresholds.
- Third-party or participant testing during the private RC.
- Compatibility promises for pre-1.0 Alpha/Beta artifacts, downgrading saves into older builds, or 1.1+ formats.
- A third Act, changes to normal two-Act progression, or campaign rewards for playing the sample.
- Choosing a source-code license now. That decision is required at the public go/no-go and blocks the visibility change until resolved.

## 2. Guided Sample requirements

The current onboarding consists of five short Battle prompts. It does not guide tile selection/commit, route selection, rewards, or economy decisions, and its progress currently accepts broad state-change events instead of verifying the named action. Stage 5 should provide a compact, interactive path through the essential gameplay decisions.

The optional Guided Sample must:

1. Be entered and exited separately from a normal Run, be skippable and restartable, and use isolated sample state. It must not create or change campaign saves, rewards, unlocks, currencies, or meta-progression.
2. Remain a short curated vertical slice, not the full two-Act campaign. Include Character and Contract choice, route selection, a Battle, a reward, and one curated Event, Shop, and Workshop interaction or an equally clear guided preview of each screen’s decision. End with a compact sample-complete state.
3. Teach the decision loop through action: select one or more tiles, inspect the legal choices exposed by that selection, then commit or cancel. Use short localized callouts, visual emphasis, and contextual details; avoid a manual-length sequence of prose.
4. Let players practice the core Battle actions: Draw, End Turn, Pattern settlement, Reserve/Discard/Swap, a Technique, and Complete Hand. Advance instruction only after the intended action is actually completed; merely seeing a state change is not enough.
5. Explain the essential data when it first matters: enemy HP and Intent, Pressure and its limit, Integrity/Stability, TP, Reserve capacity, wall, Yaku/hand progress, Gold, Refinement Tokens, and route risk/reward. Boss phase can be introduced when shown by the sample.
6. Preserve mouse/keyboard/controller reachability, focus, back/cancel, and skip behavior. Keep Settings and presentation preferences outside the gameplay teaching path.
7. Keep the normal Run’s onboarding and Help concise and consistent with the sample. Every new player-facing string uses stable localization keys and is supplied in each supported locale.

The Sample is successful when scripted tests verify the intended action sequence and isolation invariants. With no outside testers, scripted completion does **not** establish player comprehension or usability; report those as unverified.

The current scripted path and remaining human-evidence limits are recorded in [Stage 5 Guided Sample evidence](STAGE_5_GUIDED_SAMPLE_EVIDENCE.md).

## 3. Candidate build and compatibility

### Build identity and artifact

Before RC testing, pin the exact Godot stable version used for import, tests, and Windows export. Record the source commit, application version, content identity, save/replay schema versions, engine version, and output hashes together.

Create a repeatable Windows x64 export and package process. Candidate metadata must identify the release candidate instead of the stale Stage 3 development version. The current package pipeline records the candidate version and the source, content, save/replay, engine, and artifact identities. The proposed distribution artifact is a portable ZIP containing only the files needed to run the exported game. No installer or auto-updater is in scope.

The build must launch without a local developer path or editor dependency. Include concise extraction/launch instructions and release notes with the public artifact.

### Save and replay support

- Treat 1.0.0 as the first supported public format baseline. Private RC data may reset.
- Preserve immutable 1.0.0 save/suspend and replay fixtures from the frozen candidate.
- For each 1.0.x patch candidate, test loading and continuing older supported 1.0.x save fixtures, plus replay compatibility under the declared policy. Compare authoritative checkpoints and deterministic replay outcomes where applicable.
- Do not rewrite the original compatibility fixtures. Record each tested source format, target patch, and result.
- Do not claim compatibility for 1.1+, downgrades, or unpublished pre-1.0 artifacts without a later scope decision.

The current RC1 fixture identities, hashes, focused test evidence, and the remaining cross-patch limitation are recorded in [the Stage 5 save/replay baseline report](STAGE_5_SAVE_REPLAY_BASELINE.md).

## 4. Verification gates

### Gate A — RC entry

All must pass before creating the private candidate:

- Exact engine, source, content, application, save, and replay identities are recorded.
- Windows 10/11 x64 export and portable package are generated through the documented process; package and SHA-256 are recorded.
- Project import, full automated suite, localization audit, content/pool/map validation, and applicable Phase 2/Alpha regressions pass.
- Run the fixed, reproducible 1,000-seed, two-Act correctness corpus against this frozen candidate. This is correctness and determinism evidence, not a performance target.
- 1.0.0 save/replay fixtures exist and pass the declared tests.
- Guided Sample scripted coverage verifies required actions, localization, skip/restart, no campaign-state mutation, and expected HUD explanations.
- There are zero unresolved P0/P1 defects. Every remaining P2 has an owner and an explicit fix, defer, or accepted-risk disposition.

Use the Stage 4 Beta definitions: P0 covers crashes, data loss, soft-locks, invalid authoritative state, and determinism/replay corruption; P1 covers blocked required Run, reward, input, save, or replay paths. Record unverified evidence separately from passing checks.

### Gate B — Private RC validation

- Freeze a candidate identifier (for example, 1.0.0-rc.1), source commit, exported ZIP, and artifact hash.
- Keep the repository private and the candidate owner-only. Do not publish the public GitHub Release during this gate.
- The maintainer tests clean extraction/launch, settings and resolution behavior, the Guided Sample, a normal two-Act Run, save/resume, Run completion, and clean exit on Windows 10 x64 and Windows 11 x64. Record the exact OS builds used.
- Re-run the full automated gate on the frozen candidate. Any source change creates a new candidate and invalidates affected evidence.
- Record RC findings and dispositions. This gate does not imply that external player comprehension has been measured.

### Gate C — Public go/no-go

This is a separate maintainer decision after private RC validation. Before changing repository visibility:

- Resolve the root source-license choice. There is currently no root LICENSE; do not infer or add a license.
- Review source history, files, GitHub Actions history/logs/artifacts, and release materials for secrets, personal/private data, or content that must remain private.
- Confirm rights and required attribution for every redistributed asset and release component.
- Confirm the public-facing README, support contact/process, version notes, compatibility statement, and Windows requirements are accurate.
- Reconfirm the RC gates and defect dispositions against the exact release commit.

The current repository is private. [GitHub's visibility guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility) states that making it public exposes its code and Actions history and allows public forks. Because the user selected this same repository for the public GitHub Release, the approved sequence is: private RC → owner validation → separate go/no-go and public-readiness audit → change repository visibility → publish the GitHub Release → verify the public download. The go/no-go must explicitly authorize the visibility change and publication.

After publication, download the ZIP from the public release page on a clean Windows 10/11 x64 environment and repeat launch, save creation/continuation, and exit checks. Record the public tag, release URL, artifact hash, tested OS builds, and outcome.

## 5. Release evidence

The Stage 5 evidence report must identify the exact source commit and all build/content/save/replay versions, engine version, test commands, candidate/public tag, artifact hashes, Windows build numbers, compatibility fixtures and results, defect dispositions, and gate decisions.

Every area is marked **PASS**, **FAIL**, **WAIVED**, or **UNVERIFIED** with its evidence. No numeric performance result is required. Do not turn absent outside testers or player-comprehension evidence into a PASS.

## 6. Related project decisions

- [Project Spec — Stage 5](PROJECT_SPEC.md#stage-5--10-release-candidate)
- [Stage 4 Beta gate](STAGE_4_BETA_SPEC.md)
- [Stage 4 Beta evidence](STAGE_4_BETA_EVIDENCE_REPORT.md)
- [Stage 3 continuous two-Act Run contract](STAGE_3_ALPHA_SPEC.md#3-continuous-two-act-run-contract)
