---
name: vuln-scan
description: Scan dependencies for security vulnerabilities and perform safe, incremental updates with automatic rollback on test failures
argument-hint: "[scan|update|update-critical|interactive]"
allowed-tools: [Bash, Read, Glob, Grep, Edit, Write, AskUserQuestion]
---

# Dependency Vulnerability Scanner

Scan dependencies for security vulnerabilities and safely update them with automatic rollback on failures.

## Modes

| Mode | Command | Behavior |
|------|---------|----------|
| Scan only | `/vuln-scan` or `/vuln-scan scan` | Report vulnerabilities, no changes |
| Critical updates | `/vuln-scan update-critical` | Auto-update CRITICAL/HIGH only |
| Update all | `/vuln-scan update` | Update all with fixes available |
| Interactive | `/vuln-scan interactive` | Ask before each update |

## Workflow

### Phase 1: Project Understanding

**Step 1: Check for Makefile first**

Makefile is a universal build tool and often documents how to build/test projects:

```bash
# Check if Makefile exists
ls Makefile 2>/dev/null
```

If present, read it and identify targets:
- `test` or `check` - testing
- `build` or `all` - building
- `install` or `deps` - dependency installation
- `lint` - linting

Use Makefile targets as the preferred commands for verification.

**Step 2: Identify manifest files**

Look for dependency manifests to understand the ecosystem:

```bash
# Find manifest files
ls build.gradle build.gradle.kts package.json requirements.txt pyproject.toml Cargo.toml go.mod pom.xml Gemfile composer.json 2>/dev/null
```

Read discovered files to understand dependency structure.

**Step 3: Infer build/test commands**

If no Makefile, infer from project structure:

| Discovery | Test Command | Build Command |
|-----------|--------------|---------------|
| `package.json` with `"test"` script | `npm test` | `npm run build` (if exists) |
| `pytest.ini` or `pyproject.toml` with pytest | `pytest` | - |
| `setup.py` | `python setup.py test` | `python setup.py build` |
| `Cargo.toml` | `cargo test` | `cargo build` |
| `build.gradle.kts` | `./gradlew test` | `./gradlew build` |
| `build.gradle` | `./gradlew test` | `./gradlew build` |
| `go.mod` | `go test ./...` | `go build ./...` |
| CI config (`.github/workflows/*.yml`) | Parse for test commands | Parse for build commands |

**Step 4: Infer dependency update method**

| Manifest | Lockfile | Update Command |
|----------|----------|----------------|
| `package.json` | `package-lock.json` | `npm install <pkg>@<version>` |
| `package.json` | `yarn.lock` | `yarn upgrade <pkg>@<version>` |
| `package.json` | `pnpm-lock.yaml` | `pnpm update <pkg>@<version>` |
| `requirements.txt` | - | Edit file, run `pip install -r requirements.txt` |
| `pyproject.toml` | `poetry.lock` | `poetry update <pkg>` |
| `pyproject.toml` | `uv.lock` | `uv lock --upgrade-package <pkg>` |
| `Cargo.toml` | `Cargo.lock` | `cargo update -p <pkg>` |
| `go.mod` | `go.sum` | `go get <pkg>@<version>` |
| `Gemfile` | `Gemfile.lock` | `bundle update <pkg>` |
| `composer.json` | `composer.lock` | `composer update <pkg>` |

### Phase 2: Pre-flight Checks

1. **Check for trivy installation:**
```bash
which trivy || nix-shell -p trivy || echo "trivy not found"
```
If not installed, inform user: "trivy is required. Install via: brew install trivy, apt install trivy, or see https://trivy.dev"

2. **Verify clean git state:**
```bash
git status --porcelain
```
If output is non-empty, abort: "Working directory has uncommitted changes. Please commit or stash before running vuln-scan."

3. **Confirm commands are identified:**
If build/test commands are unclear, ask user with AskUserQuestion:
- "What command runs your tests?"
- "What command builds your project?"

4. **Create checkpoint tag:**
```bash
git tag -f vuln-scan-checkpoint-$(date +%Y%m%d-%H%M%S)
```

### Phase 3: Vulnerability Scan

Run trivy filesystem scan:
```bash
trivy fs . --format json --scanners vuln 2>/dev/null
```

Save output to parse. See `references/trivy-guide.md` for JSON structure details.

### Phase 4: Parse and Prioritize

Extract from JSON output:
- Package name (`PkgName`)
- Installed version (`InstalledVersion`)
- Fixed version (`FixedVersion`)
- CVE ID (`VulnerabilityID`)
- Severity (`Severity`)

Filter to only vulnerabilities with `FixedVersion` available.

Priority order (see `references/severity-matrix.md`):
1. CRITICAL
2. HIGH
3. MEDIUM
4. LOW

Group by package to avoid duplicate updates.

### Phase 5: Mode-Specific Behavior

**Scan mode** (`scan`):
- Display vulnerability table
- Show count by severity
- List packages without fixes available
- Exit without changes

**Update modes** (`update`, `update-critical`, `interactive`):

For each vulnerability with fix (in priority order):

1. **Create pre-update tag:**
```bash
git tag -f vuln-scan-pre-<pkg>-$(date +%s)
```

2. **Interactive mode only:** Ask user with AskUserQuestion:
   - "Update <pkg> from <old> to <new> to fix <CVE>?"
   - Options: "Yes", "Skip", "Abort all"

3. **Update single dependency** using inferred update command

4. **Run build** (if applicable):
```bash
make build  # or inferred build command
```

5. **Run tests:**
```bash
make test  # or inferred test command
```

6. **If tests pass:**
```bash
git add -A
git commit -m "fix(deps): update <pkg> to <version>

Fixes <CVE-ID> (<severity>)"
```

7. **If tests fail:**
```bash
# Rollback to pre-update tag
git checkout -- .
git clean -fd
```
Ask user: "Update of <pkg> failed tests. Skip and continue, or abort?"

### Phase 6: Generate Report

Output a summary:

```
## Vulnerability Scan Report

### Updated Packages
- <pkg>: <old> → <new> (fixes CVE-XXXX)

### Failed Updates
- <pkg>: Tests failed after updating to <version>

### No Fix Available
- <pkg> <version>: CVE-XXXX (SEVERITY) - No fix available yet

### Summary
- X vulnerabilities found
- Y packages updated
- Z updates failed
- W awaiting upstream fixes
```

## Error Handling

- **trivy not installed:** Provide installation instructions, abort
- **Git not clean:** List uncommitted changes, abort
- **Unknown project type:** Ask user for build/test commands
- **Update command fails:** Rollback, report error, continue or abort
- **Tests fail:** Rollback, ask user whether to skip or abort
- **No vulnerabilities found:** Report clean scan, exit

## Safety Guarantees

1. **Single dependency updates:** One package at a time for isolation
2. **Automatic rollback:** Git tags created before each update
3. **Test verification:** Build + tests must pass before committing
4. **User confirmation:** Interactive mode and on any failure
5. **Clean state required:** Abort if uncommitted changes exist
6. **No force operations:** Never use `--force` on git operations
