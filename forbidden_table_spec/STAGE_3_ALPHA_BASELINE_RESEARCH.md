# Stage 3 Alpha — Current PC Baseline Research

**Issue:** [#42](https://github.com/sunnyday9/Forbidden-Table/issues/42), kept separate from readiness audit #41

**Captured:** 2026-09-23
**Checkout:** `research/stage3-alpha-readiness`, `622ff72` (`test: add Stage 2 exit review evidence`)

## Finding

The existing Phase 2 test suite and deterministic replay/exit-review fixtures run successfully in the available WSL2 environment. They provide a reproducible baseline for test-process execution and memory use, but **not** a gameplay frame-rate, complete-run throughput, or large-batch simulation baseline. No standalone simulation or benchmark runner was found under `scripts/`, `tests/`, or `src/`.

These measurements are observations only. They do not define future Alpha pass/fail thresholds. The Alpha plan explicitly calls for large seeded batches and performance benchmarks, which these existing regression workloads do not supply ([Implementation Plan](IMPLEMENTATION_PLAN.md#L494-L501)).

## Machine and build context

- WSL2 Linux: `LAPTOP-JIRRTHIQ`, kernel `6.6.87.2-microsoft-standard-WSL2`, x86-64.
- CPU reported by `lscpu`: AMD Ryzen 7 H 260 with Radeon 780M Graphics; 8 cores / 16 threads; Microsoft full virtualization. `nproc` reported 16. The observed cgroup CPU and memory limits were `max`.
- `free -h` snapshot: 15 GiB RAM, about 13 GiB available, 4 GiB swap.
- `project.godot` pins Godot 4.7.2 ([project config](../project.godot#L1-L8)); the tested binary reports `4.7.2.stable.official.ed1daf0bf`. It is the cached Linux x86-64 executable at `/mnt/f/Forbidden Table/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`, SHA-256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`.
- The local Codex Godot MCP configuration points `GODOT_PATH` at `/mnt/f/zcode-harness/godot xiangqi rogue/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe`; that configured path was absent. No `godot`/`godot4` executable was on `PATH`. The cached Linux binary was therefore selected explicitly.
- The measurements were taken on WSL2, not a native Windows release build or a calibrated player PC. CPU frequency/power state was not captured.

## Method and commands

To avoid test-generated changes in the shared checkout, I ran against a temporary archive of tracked `HEAD`, with the checkout's existing ignored `.godot` cache copied into that temporary tree. XDG data/config/cache directories were also isolated under that temporary directory. The repository's `scripts/test.sh` pins Godot 4.7.2, invokes the headless runner, and has a 30-second test timeout ([wrapper](../scripts/test.sh#L4-L8), [execution](../scripts/test.sh#L75-L104)). `GODOT_BIN` was supplied explicitly so its missing-binary fallback would not download or extract files.

Isolation setup (resolved temporary directory for these measurements: `/tmp/forbidden-table-alpha-baseline.bXieso`):

```sh
baseline_dir="$(mktemp -d /tmp/forbidden-table-alpha-baseline.XXXXXX)"
git archive --format=tar HEAD | tar -x -C "$baseline_dir"
mkdir -p "$baseline_dir/.godot"
cp -a .godot/. "$baseline_dir/.godot/"
mkdir -p "$baseline_dir/xdg-data" "$baseline_dir/xdg-config" "$baseline_dir/xdg-cache"
```

Timed invocations used the resolved directory above and this executable:

```sh
godot_bin='/mnt/f/Forbidden Table/.cache/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64'
/usr/bin/time -v env GODOT_BIN="$godot_bin" \
  XDG_DATA_HOME="$baseline_dir/xdg-data" \
  XDG_CONFIG_HOME="$baseline_dir/xdg-config" \
  XDG_CACHE_HOME="$baseline_dir/xdg-cache" \
  "$baseline_dir/scripts/test.sh"

/usr/bin/time -f 'METRIC elapsed_s=%e user_s=%U system_s=%S cpu=%P max_rss_kb=%M exit=%x' \
  env GODOT_BIN="$godot_bin" XDG_DATA_HOME="$baseline_dir/xdg-data" \
  XDG_CONFIG_HOME="$baseline_dir/xdg-config" XDG_CACHE_HOME="$baseline_dir/xdg-cache" \
  "$baseline_dir/scripts/test.sh" --run-replay

/usr/bin/time -f 'METRIC elapsed_s=%e user_s=%U system_s=%S cpu=%P max_rss_kb=%M exit=%x' \
  env GODOT_BIN="$godot_bin" XDG_DATA_HOME="$baseline_dir/xdg-data" \
  XDG_CONFIG_HOME="$baseline_dir/xdg-config" XDG_CACHE_HOME="$baseline_dir/xdg-cache" \
  "$baseline_dir/scripts/test.sh" --stage2-exit-review
```

The latter two workloads were repeated 5 and 3 times respectively. `--run-replay` selects the Run Replay tests; its five unique run seeds are 9001, 9002, 9003, 9004, and 9101 (9002 is run twice for byte-stability comparison) ([runner selectors](../tests/run_tests.gd#L61-L63), [fixtures](../tests/replay_test.gd#L119-L145), [bounded battle fixture](../tests/replay_test.gd#L202-L226)). `--stage2-exit-review` selects the composite Phase 2 exit evidence suite; its direct entry fixture uses seed 2039 and the suite also invokes existing fixed test fixtures ([runner](../tests/run_tests.gd#L75-L75), [review](../tests/stage2_exit_review_test.gd#L25-L60)). These are fixed regression fixtures, not a generated seed batch. The Phase 2 spec requires deterministic comparisons of repeated commands, suspend/resume, replay, and seeded map/reward/shop/event scenarios ([determinism evidence](PHASE_2_SPEC.md#L763-L773)).

## Observed measurements

All rows below are successful invocations. Wall/user/system are seconds; CPU is GNU `time`'s percentage; RSS is maximum resident set in KiB.

| Workload / trial | Wall | User | System | CPU | Max RSS | Result |
|---|---:|---:|---:|---:|---:|---|
| Full suite 1 | 3.40 | 2.32 | 0.39 | 80% | 155,224 | Pass |
| Full suite 2 | 6.19 | 3.76 | 0.62 | 70% | 155,732 | Pass |
| Full suite 3 | 5.20 | 3.38 | 0.49 | 74% | 155,120 | Pass |
| Run Replay 1 | 12.27 | 1.54 | 0.55 | 17% | 153,032 | Pass |
| Run Replay 2 | 2.54 | 1.53 | 0.41 | 76% | 153,260 | Pass |
| Run Replay 3 | 2.44 | 1.49 | 0.37 | 76% | 153,232 | Pass |
| Run Replay 4 | 4.21 | 2.22 | 0.47 | 64% | 153,296 | Pass |
| Run Replay 5 | 4.19 | 2.12 | 0.59 | 64% | 152,528 | Pass |
| Stage 2 exit review 1 | 3.08 | 2.05 | 0.45 | 81% | 152,988 | Pass |
| Stage 2 exit review 2 | 2.84 | 1.98 | 0.34 | 81% | 153,268 | Pass |
| Stage 2 exit review 3 | 3.19 | 2.12 | 0.46 | 81% | 153,076 | Pass |

Observed wall-time ranges (median): full suite 3.40–6.19 s (5.20 s); Run Replay 2.44–12.27 s (4.19 s); Stage 2 exit review 2.84–3.19 s (3.08 s). The first Run Replay trial is a pronounced wall-time outlier: its 2.09 s combined user/system CPU does not explain its 12.27 s elapsed time. No cause was established; retain it in the sample rather than silently excluding it. RSS stayed around 149–152 MiB across these processes.

## Errors, limitations, and disposition

- A first run in a clean `git archive` failed with Godot compile/parse errors, beginning with unresolved global class `BattleController`; the archive omitted the ignored `.godot` global-class cache. Copying the existing cache into the temporary tree resolved this and the measured invocations passed. This is a test-environment/setup limitation, not evidence of a source fix.
- The wrapper's built-in 30-second timeout did not fire on any successful trial. The only test errors were in that initial cache-less attempt.
- These timings include wrapper/process startup and headless test execution. They are not an in-game frame-time test, do not measure a complete run's simulation throughput, and do not cover a large seed population. No seed-sweep count or gameplay-completion distribution can be claimed.
- Smallest useful next benchmark workload, if a numeric run-throughput baseline is required: a documented deterministic command policy that completes one currently supported Phase 2 run on a named seed, repeated under the same build while recording accepted-command count, checkpoints, outcome, wall/CPU time, and peak RSS. A later threshold decision can select a broader seed panel and pass/fail limits. This report does not build that runner or set those limits.

No production code, existing spec, or GitHub issue was changed; no commit was made. The report is specific to #42 and is not the #41 readiness report.
