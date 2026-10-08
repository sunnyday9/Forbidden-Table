# Stage 5 — GitHub Issue Proposal

**Status:** Issue map and child tickets created on 2026-10-05. No release, tag, repository visibility, or license setting has been changed.

**GitHub map:** [#101 — Stage 5](https://github.com/sunnyday9/Forbidden-Table/issues/101)

**Parent map title:** Stage 5 — Windows 1.0 Release Candidate and Public Release
**Map label:** wayfinder:map
**Child labels:** wayfinder:task; use ready-for-agent only after acceptance checks are implementation-ready
**Human gate labels:** wayfinder:task and ready-for-human
**Canonical scope:** [Stage 5 release spec](STAGE_5_RELEASE_SPEC.md)

The proposed bodies below are the source record for the created issues. The map is not release authorization. GitHub sub-issue links and native dependency edges have been applied and verified.

## Proposed dependency order

S5.1 and S5.2 can proceed in parallel. S5.3 depends on S5.1’s version identity. S5.4 waits for S5.1, S5.2, and S5.3. S5.5 waits for S5.4 and requires a maintainer decision on the source license. S5.6 waits for S5.5 and a separate explicit public go. Nothing in this proposal authorizes public visibility or publication.

## [S5.1 — #102](https://github.com/sunnyday9/Forbidden-Table/issues/102) — Pin Godot and build a repeatable Windows 10/11 x64 release package

**Type:** Implementation task
**Blocked by:** None
**Proposed labels:** wayfinder:task, ready-for-agent

**Goal:** Produce the portable Windows x64 ZIP for private RC and eventual public 1.0 using a documented, repeatable build path.

**Acceptance criteria:**

- One exact Godot stable version is recorded and used for project import, automated tests, and export.
- A Windows x64 export preset and build/package script exist. They work from a clean checkout and do not depend on a developer-specific executable path, editor session, or local project data.
- Project version metadata no longer reports the Stage 3 Alpha value. Candidate version, content identity, save/replay schema identity, source commit, and engine version can be recorded with the build.
- The output is a portable ZIP with only runtime files, concise extraction/launch instructions, and a computed SHA-256. No installer or auto-updater is added.
- The same commit can be exported twice using the documented process; differences in the package inventory or hashes are explained and recorded.

**Validation:** Run import and the full test script with the pinned engine, export from a clean checkout, inspect the ZIP contents, and launch the export without the Godot editor or any developer-local path.

## [S5.2 — #103](https://github.com/sunnyday9/Forbidden-Table/issues/103) — Add the isolated Guided Sample

**Type:** Implementation task
**Blocked by:** None
**Proposed labels:** wayfinder:task, ready-for-agent

**Goal:** Teach new players the core gameplay decisions in a short optional scenario without changing the normal two-Act Run.

**Acceptance criteria:**

- The player can enter, skip, restart, and exit a separate Guided Sample.
- Its state is isolated. Playing or abandoning it never creates or alters campaign saves, rewards, unlocks, currencies, or meta-progression.
- The curated route covers Character and Contract selection, a map choice, tile selection and legal-action preview, Battle, a reward, and the Event, Shop, and Workshop decision screens. Each stop uses one representative action or a short visual walkthrough so the sample stays shorter than the normal Run.
- Battle practice includes Draw, End Turn, Pattern settlement, Reserve/Discard/Swap, one Technique, Complete Hand, and reading enemy Intent.
- Essential HUD cues explain HP/Intent, Pressure/limit, Integrity/Stability, TP, Reserve capacity, wall, Yaku/hand progress, Gold, Refinement Tokens, and route risk/reward when each first matters.
- Progress advances only after the instructed action is actually completed. A loosely related state change cannot satisfy a step.
- Prompts use short localized text plus visual emphasis. Mouse, keyboard, and controller users can complete, skip, cancel, and restart the sample.
- Existing normal two-Act progression and its save/reward behavior remain unchanged. New text uses stable keys in each supported locale.

**Validation:** Add tests for the scenario sequence, actual-action gating, localization completeness, skip/restart, input/cancel paths, and isolation from campaign/profile state. Report player comprehension as unverified until an external study is approved and run.

## [S5.3 — #104](https://github.com/sunnyday9/Forbidden-Table/issues/104) — Establish the 1.0.0 save/replay baseline and 1.0.x patch checks

**Type:** Implementation task
**Blocked by:** S5.1
**Proposed labels:** wayfinder:task, ready-for-agent

**Goal:** Begin the compatibility promise at public 1.0.0 and carry supported formats through 1.0.x patch updates.

**Acceptance criteria:**

- Immutable fixtures are captured from the frozen 1.0.0 candidate for a save/suspend and replay.
- A later 1.0.x build can load and continue every supported earlier 1.0.x save fixture and pass the declared replay checks.
- Compatibility checks compare authoritative checkpoints and deterministic replay outcomes where applicable.
- Fixtures are never rewritten by tests. Reports identify source format, target patch, and result.
- The docs make clear that pre-1.0 distributed formats, downgrade behavior, and 1.1+ formats are outside the current commitment.

**Validation:** Run fixtures against the exact patch candidate and include them in the full automated gate.

## [S5.4 — #105](https://github.com/sunnyday9/Forbidden-Table/issues/105) — Freeze and validate the owner-only Windows 1.0 RC

**Type:** Verification task
**Blocked by:** S5.1, S5.2, S5.3
**Proposed labels:** wayfinder:task, ready-for-agent

**Goal:** Produce reviewable evidence for a frozen candidate without implying third-party testing.

**Acceptance criteria:**

- The exact RC version, source commit, engine/content/save/replay identities, portable ZIP, and SHA-256 are recorded.
- The full project suite, localization audit, content/pool/map checks, applicable Phase 2/Alpha regressions, save/replay compatibility checks, and fixed 1,000-seed two-Act correctness corpus pass on the candidate.
- Owner manual smoke tests cover clean extraction/launch, resolution/settings, Guided Sample completion, a normal two-Act Run, save/resume, completion, and clean exit on Windows 10 x64 and Windows 11 x64. The exact OS builds are recorded.
- There are zero open P0/P1 defects. Every P2 has an owner and fix, defer, or accepted-risk disposition.
- The report marks player comprehension and outside-device usability unverified; it does not claim that the owner-only test substitutes for outside testers.

**Validation:** Re-run the automated gates on the frozen candidate. A change to the candidate source creates a new RC and requires affected evidence to be repeated.

## [S5.5 — #106](https://github.com/sunnyday9/Forbidden-Table/issues/106) — Complete public-source readiness and record the go/no-go

**Type:** Maintainer gate
**Blocked by:** S5.4
**Proposed labels:** wayfinder:task, ready-for-human

**Goal:** Decide whether the validated candidate and this repository are ready to become public.

**Acceptance criteria:**

- The maintainer records a source-license decision. There is currently no root LICENSE; do not infer a license. If the source is to be open source, add the chosen license only after that decision.
- The source history, tracked files, Actions history/logs/artifacts, and release materials are reviewed for credentials, secrets, personal/private data, or material that must remain private.
- Rights and required attribution are confirmed for all redistributed assets and release components.
- Public README, launch/support instructions, compatibility statement, and release notes accurately reflect the accepted scope, including the Windows 10/11 x64 target and 1.0.x save/replay window.
- RC evidence and defect dispositions still match the exact intended release commit.
- A separate explicit go/no-go is recorded. This issue blocks repository visibility change.

**Validation:** Attach the checklist and evidence references to the issue. Do not change repository visibility while any public-readiness item or license decision is open.

## [S5.6 — #107](https://github.com/sunnyday9/Forbidden-Table/issues/107) — Publish the approved GitHub Release and verify the public download

**Type:** Maintainer publication gate
**Blocked by:** S5.5
**Proposed labels:** wayfinder:task, ready-for-human

**Goal:** Publish public 1.0 from the approved commit only after the private RC and public-readiness gates pass.

**Acceptance criteria:**

- The maintainer has explicitly approved the public go/no-go and repository visibility change.
- The current repository is made public before the GitHub Release is published, preserving the agreed same-repository distribution path.
- The public release uses the approved 1.0.0 tag, release notes, portable ZIP, and matching SHA-256.
- A fresh download from the public release page is tested on clean Windows 10 and Windows 11 x64 environments for launch, save creation/continuation, and clean exit.
- The release URL, tag, artifact hash, exact OS builds, and test outcomes are recorded.

**Validation:** Verify the public release page and artifact from a clean download. This issue is the only proposed action that changes repository visibility or publishes the game.

## Tracker state

- The current tracker has wayfinder:map, wayfinder:task, ready-for-agent, and ready-for-human labels.
- Map #101 contains all six child issues. Native blockers are #104 ← #102; #105 ← #102, #103, #104; #106 ← #105; and #107 ← #106.
- Only #102 is being claimed for implementation now. No public action has been assigned or executed.
