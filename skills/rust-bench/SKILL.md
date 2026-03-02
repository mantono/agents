---
name: rust-bench
description: Profile a Rust binary, capture a baseline, benchmark before/after changes, and interpret results using Amdahl's Law
argument-hint: "[profile|baseline|bench|memory|all]"
allowed-tools: [Bash, Read, Glob, Grep, AskUserQuestion]
---

# Rust Performance Benchmarking Skill

Guide a full Rust performance benchmarking workflow — profiling, baseline capture, post-optimisation comparison, and result interpretation.

## Modes

| Mode | Command | Behaviour |
|------|---------|-----------|
| `baseline` | `/rust-bench baseline` | Build release binary, measure and save baseline timings |
| `profile` | `/rust-bench profile` | CPU profiling with `perf` or `cargo flamegraph`; annotates hotspots |
| `bench` | `/rust-bench bench` | Build current binary, compare to baseline, interpret with Amdahl's Law |
| `memory` | `/rust-bench memory` | Memory profiling with `heaptrack` or `valgrind --tool=massif` |
| `all` (default) | `/rust-bench` | Full workflow: baseline → profile → (user makes changes) → bench |

**Always set `TMPDIR=/tmp/claude-1000/` for all `cargo` invocations in this environment.**

---

## Phase 1: Project Discovery

**Step 1: Find `Cargo.toml`**

```bash
find . -maxdepth 3 -name "Cargo.toml" | head -5
```

Read it to extract:
- `[package] name` — the crate name (used for binary name and baseline file naming)
- `[[bin]]` sections — if multiple binaries exist, ask the user which to benchmark

**Step 2: Ask for the benchmark command**

If the binary name does not map to an obvious invocation, ask:

> "What command should I benchmark? (e.g. `./target/release/<bin> --flag /some/path`)"

Store the answer as `BENCH_CMD`. The baseline binary invocation will substitute the binary path but keep all flags.

**Step 3: Check for available tools**

```bash
which perf hyperfine cargo-flamegraph heaptrack 2>/dev/null
```

- If `hyperfine` is missing: `nix-shell -p hyperfine --run "hyperfine --version"` to verify it can be obtained
- If `perf` is missing and `profile` mode is requested: fall back to `cargo flamegraph`
- If neither profiler is available: report clearly and ask the user to install one before continuing

---

## Phase 2: `baseline` mode

**Rule: always benchmark release builds. Debug binaries have no value for performance work.**

### Step 1: Build release binary

```bash
TMPDIR=/tmp/claude-1000/ cargo build --release 2>&1
```

If the build fails, report the error and stop — do not benchmark a stale binary.

### Step 2: Copy baseline binary

Identify the binary path (usually `target/release/<crate-name>`). Copy it:

```bash
cp target/release/<crate-name> /tmp/claude-1000/<crate-name>-baseline
chmod +x /tmp/claude-1000/<crate-name>-baseline
```

### Step 3: Warm the page cache (if CPU-bound is suspected)

Run the command once before the timed runs so disk I/O does not contaminate the CPU measurement:

```bash
<BENCH_CMD> > /dev/null 2>&1
```

### Step 4: Measure with hyperfine

```bash
hyperfine --warmup 3 --runs 10 --shell none '<BENCH_CMD>'
```

Parse the output. Extract from the summary lines:
- **Mean** wall-clock time and standard deviation
- **User CPU time** (time process spent in user-space)
- **System time** (time the kernel spent on behalf of the process)

Add `--export-json /tmp/claude-1000/hyperfine-baseline.json` to get machine-readable output for later comparison.

### Step 5: Diagnose the bottleneck

Compute the System fraction:

```
system_fraction = System / (User + System)
```

| system_fraction | Diagnosis | Implication |
|----------------|-----------|-------------|
| > 0.5 | **I/O-bound** (syscall / disk / network dominates) | CPU micro-optimisations will not move wall-clock time — tell the user clearly |
| 0.3 – 0.5 | **Mixed** | Both directions may help; start with the larger fraction |
| < 0.3 | **CPU-bound** | Profiling and algorithmic changes will be effective |

**If the workload is I/O-bound, stop and tell the user:** "System time is X% of total CPU time. This workload is I/O-bound. Optimising user-space code (HashMap, allocations, etc.) will not significantly improve wall-clock performance. Consider reducing I/O: batching reads, changing buffering strategy, or parallel I/O."

### Step 6: Tag the baseline commit

```bash
BASELINE_TAG="bench-baseline-$(date +%Y%m%d-%H%M%S)"
git tag -f "$BASELINE_TAG"
echo "Tagged: $BASELINE_TAG"
```

This ties the baseline binary to an exact code state — the user can `git checkout <tag>` and rebuild it at any time.

### Step 7: Save baseline metadata

Write to `/tmp/claude-1000/rust-bench-baseline.env`:

```
BASELINE_BIN=/tmp/claude-1000/<crate-name>-baseline
BASELINE_CMD=<full baseline command with substituted binary path>
BASELINE_TAG=<tag name>
BASELINE_MEAN_MS=<mean in milliseconds>
BASELINE_USER_S=<user time seconds>
BASELINE_SYSTEM_S=<system time seconds>
BENCH_CMD=<original bench command>
```

Report back to the user:
- Mean time, σ
- Bottleneck diagnosis
- Git tag name
- Path to baseline binary

---

## Phase 3: `profile` mode

Ask the user which profiler to use:

> "Which profiler should I use?"
> - `perf` — symbol-level CPU cost, text output, low overhead, Linux only
> - `cargo flamegraph` — visual SVG flame graph, more portable

### perf workflow

```bash
perf record -g --call-graph dwarf -- <BENCH_CMD>
perf report --stdio --no-pager | head -80
```

Parse `perf report` output:
- Extract the top 10 symbols by the `%` column (the self-cost column, not the cumulative)
- For each symbol in the top 5, explain its Rust meaning:
  - `DefaultHasher::write` / `SipHash` → per-byte hashing of HashMap keys; consider `FxHashMap` or `AHashMap`
  - `clone` / `to_owned` / `into_owned` → unnecessary allocation; look for owned→borrowed conversions
  - `fmt` / `Display` / `format_args` → formatting overhead in hot path; consider lazy formatting
  - `alloc` / `malloc` / `jemalloc` → allocator pressure; consider arena allocation or pre-sizing containers
  - `regex::exec` → regex compilation in hot loop; compile once and cache
  - `BufReader` / `read` → I/O; already diagnosed in Phase 2

### cargo flamegraph workflow

```bash
nix-shell -p cargo-flamegraph --run "TMPDIR=/tmp/claude-1000/ cargo flamegraph -- <args-only, no binary prefix>"
```

Report:
- Location of generated `flamegraph.svg` (project root by default)
- Describe the dominant stacks: "The widest bars are in `<module>::<fn>`, accounting for approximately X% of sampled time"

### Amdahl's Law projection

After identifying the dominant hotspot fraction `p` (e.g. 0.55 for 55% of CPU time):

```
Max theoretical speedup = 1 / (1 - p)
```

Tell the user: "If the profiled hotspot is truly X% of total runtime and you eliminate it entirely, the maximum possible wall-clock speedup is Y×. Set this as your ceiling expectation before making changes."

---

## Phase 4: `bench` mode

### Step 1: Build current release binary

```bash
TMPDIR=/tmp/claude-1000/ cargo build --release 2>&1
```

### Step 2: Load baseline

Read `/tmp/claude-1000/rust-bench-baseline.env`. If the file does not exist, instruct the user to run `/rust-bench baseline` first.

### Step 3: Warm page cache

```bash
<BENCH_CMD> > /dev/null 2>&1
```

### Step 4: Run hyperfine comparison

```bash
hyperfine \
  --warmup 3 \
  --runs 10 \
  --shell none \
  --export-json /tmp/claude-1000/hyperfine-bench.json \
  '<BASELINE_CMD>' \
  '<BENCH_CMD>'
```

### Step 5: Parse and interpret results

From `hyperfine-bench.json`, extract for each command:
- `mean` (seconds)
- `stddev`
- `user`, `system` (seconds)

Compute:
- **Absolute delta**: `baseline_mean - current_mean` in ms
- **Speedup ratio**: `baseline_mean / current_mean`
- **Noise threshold**: if `abs(delta) < 2 * max(baseline_stddev, current_stddev)`, the result is within noise

**Amdahl's Law sanity check** (if a hotspot fraction `p` was identified in `profile` mode):

```
theoretical_max_speedup = 1 / (1 - p)
```

If `measured_speedup > theoretical_max_speedup`, something unexpected happened (check if the workloads are truly equivalent). If `measured_speedup << theoretical_max_speedup`, explain why — likely the System-time floor: even if user-space is infinitely fast, kernel time sets a lower bound on wall-clock time.

**Verdict**:

| Condition | Verdict |
|-----------|---------|
| `delta > 2σ` and `speedup > 1.05` | ✅ Meaningful improvement |
| `abs(delta) <= 2σ` | ⚪ Within noise — no measurable change |
| `speedup < 0.95` | ❌ Regression — current build is slower |

Print the verdict clearly, including the raw numbers so the user can sanity-check.

---

## Phase 5: `memory` mode

### heaptrack (preferred)

```bash
nix-shell -p heaptrack --run "heaptrack ./target/release/<crate-name> <args>"
```

After the run, heaptrack writes a `.zst` file. Analyse it:

```bash
nix-shell -p heaptrack --run "heaptrack_print <heaptrack-output-file>.zst 2>/dev/null | head -80"
```

Report:
- Peak heap allocation
- Top 5 allocation sites by total bytes

### valgrind massif (fallback)

```bash
nix-shell -p valgrind --run "valgrind --tool=massif --pages-as-heap=yes ./target/release/<crate-name> <args>"
ms_print massif.out.* | head -60
```

Note: `--pages-as-heap=yes` captures all memory including stack and mmap, giving a more complete picture but with higher overhead.

---

## Phase 6: `all` mode (default)

Run the full workflow in order:

1. **Project discovery** (Phase 1) — identify binary and benchmark command
2. **baseline** (Phase 2) — build, measure, save
3. Prompt the user: "Baseline captured. Now make your code changes. When ready, press Enter to continue with profiling and benchmarking."
4. **profile** (Phase 3) — identify hotspots, set Amdahl ceiling
5. Prompt the user: "Profile complete. Apply your optimisations now. When ready, press Enter to run the before/after comparison."
6. **bench** (Phase 4) — compare and interpret
7. If `memory` mode is also requested, run Phase 5 after bench.

---

## Key Principles

1. **Always benchmark release builds.** Debug builds have no value for performance work. Never skip `--release`.
2. **Warm the page cache** before a CPU comparison — run the command once before `hyperfine` starts if the bottleneck is CPU-bound.
3. **Never optimise a System-time bottleneck from user space.** If `System / (User + System) > 0.5`, tell the user clearly and explain why user-space changes won't help.
4. **Apply Amdahl's Law before promising speedups.** If perf says a hotspot is 55% of CPU time, the maximum possible wall-clock speedup is ~2.2×, even with perfect elimination.
5. **TMPDIR must be set** for all `cargo` invocations: `TMPDIR=/tmp/claude-1000/`.
6. **Tie baselines to commits** with `git tag` so measurements can always be reproduced.
7. **Single runs are meaningless.** Always use `hyperfine --warmup 3 --runs 10` minimum; quote the command to `--shell none` to avoid shell overhead inflating results.
