# Installer Consistency Review

**Date:** 2026-03-15
**Reviewer:** worker-b6795a9c-1

---

## TL;DR — Critical Issues

| # | Severity | Finding |
|---|----------|---------|
| 1 | HIGH | install.sh PRESERVE list missing .update-state.json and VERSION — data loss on update |
| 2 | HIGH | update.mjs does NOT check tar exit code — partial extraction silently clobbers install |
| 3 | MEDIUM | update.mjs has no sha256 verification — auto-update.ts and install.sh both do |
| 4 | MEDIUM | Tarball is stale — built Mar 12, 5+ extension files changed since |
| 5 | MEDIUM | VERSION not in .gitignore — generated at build time, should be git-ignored |
| 6 | LOW | update.mjs has .git in PRESERVE; auto-update.ts does not |
| 7 | LOW | Zero Windows compatibility in any of the 4 implementations |

---

## 1. PRESERVE Lists — Detailed Comparison

Three locations preserve user files across updates. They are NOT in sync.

### auto-update.ts PRESERVE_FILES
.env, settings.json, governance, sessions, .helios, auth.json,
run-history.jsonl, mcp.json, dep-allowlist.json, .secrets, state, models.json,
pi-messenger.json, .update-state.json, VERSION

### update.mjs PRESERVE
Same as above PLUS: .git

### install.sh (for preserve in ...)
.env settings.json governance sessions .helios auth.json run-history.jsonl
mcp.json dep-allowlist.json .secrets state models.json pi-messenger.json
MISSING: .update-state.json
MISSING: VERSION

### Findings

install.sh is missing 2 entries:

1. .update-state.json — Contains auto-update state. Without it in PRESERVE, re-installs
   via team-installer silently reset update tracking state.

2. VERSION — The installed version identifier. install.sh reads PI_AGENT_DIR/VERSION to
   decide if update is needed. Preserving it explicitly avoids a timing window.

update.mjs has .git that auto-update.ts does not. On git-clone installs, preserving .git
prevents wiping git history (intentional). On tarball installs .git does not exist so
harmless — but undocumented divergence is a maintenance hazard.

### Fix Required

Add .update-state.json and VERSION to install.sh PRESERVE list.
The list appears in 4 places (2x stash loops, 2x restore loops). All 4 need updating.

---

## 2. VERSION File

### Current State
- ~/.pi/agent/VERSION: does NOT exist on development machine
- ~/helios-team-installer/dist/VERSION: exists, value is 06.14.0
- helios-agent-latest.tar.gz: contains helios-agent-v06.14.0/VERSION (verified via tar -t)

### Generation Flow
build-release.sh line 176 writes VERSION into the stage dir, included in tarball. Correct.
install.sh lines 389-391: fallback writes VERSION if not present after extraction.
update.mjs lines 86-88: explicitly writes remoteVersion to VERSION after update.

### VERSION not in .gitignore
~/.pi/agent/.gitignore does not list VERSION. Since VERSION is generated at build time
and does not exist in dev mode, it should be gitignored to prevent untracked-file noise.

Recommended: Add VERSION to ~/.pi/agent/.gitignore

---

## 3. Release Tarball

### Build Script: build-release.sh
- Reads version from ~/helios-package/package.json or explicit arg
- Stages to TMPDIR/helios-agent-v{VERSION}/
- Writes VERSION file into stage
- Creates tar.gz with sha256 checksum
- Copies to dist/helios-agent-latest.tar.gz (always-latest alias)

### Tarball is Stale
Latest tarball: Mar 12 09:48. Source files changed after that date:

  extensions/subagent-mesh.ts              (new subagent mesh coordination)
  extensions/hema-dispatch/index.ts        (warm proactive agents)
  extensions/hema-dispatch/suggestion-queue.ts
  extensions/preflight-enforcer/index.ts   (governance enforcement)
  extensions/session-reaper.ts
  setup.sh

Team members installing from the current release will get 3-day-old extension code.
hema-dispatch and subagent-mesh are recently completed significant features.

Recommended: Run ./build-release.sh <next-version> and push a new GitHub release.

---

## 4. Duplicate Update Logic — Consistency Audit

4 independent implementations of the tarball update flow.

  Feature                         | auto-update.ts | update.mjs | install.sh upd | install.sh inst
  --------------------------------|----------------|------------|----------------|----------------
  Version check before download   | YES            | YES        | YES            | N/A
  SHA256 verification             | YES            | NO [BUG]   | YES            | YES
  Stash user files before extract | YES            | YES        | YES            | YES
  Check tar exit code             | YES            | NO [BUG]   | YES            | YES
  Restore stash on tar failure    | YES            | NO [BUG]   | YES            | YES
  Cleanup temp files on failure   | YES            | partial    | YES            | YES
  Write VERSION after update      | YES            | YES        | YES (fallback) | YES (fallback)

### CRITICAL: update.mjs tar failure is silent

update.mjs line 75 calls run() but discards the return value:

  run(tar -xzf tarball ..., { timeout: 30_000 });  // return value IGNORED

The run() function returns false on failure. If tar fails (corrupt download, disk full,
permission error), the code:
  1. Continues to restore stash files into a partially clobbered agent directory
  2. Writes a new VERSION file as if update succeeded
  3. Reports success

The agent directory ends up in an inconsistent state with no rollback path.

Compare to auto-update.ts which wraps in try/catch and returns error with reason.

Fix: Change line 75 to check the return value. On failure: restore stash, cleanup, exit(1).

### update.mjs missing sha256 check
Both auto-update.ts and install.sh verify sha256 before extracting. update.mjs skips this.
A corrupted or tampered tarball would be extracted silently.

### Error handling divergence
- auto-update.ts: fails closed, returns { ok: false, reason }, shows user message
- update.mjs: process.exit(1) on download failure, silent continue on extract failure (BUG)
- install.sh: returns 0 (no-op), logs warn, restores from backup (most conservative)

---

## 5. Windows Compatibility

### Verdict: No Windows story

Both auto-update.ts and update.mjs use Unix-only commands with zero platform branching:

  curl                   — not on Windows without manual install
  tar --strip-components — GNU extension; no Windows native equivalent
  shasum -a 256          — macOS/Linux only (auto-update.ts)
  cp -a                  — Unix flag not on Windows (auto-update.ts)
  rm -rf                 — Unix shell syntax

Neither file checks process.platform. No PowerShell fallback. No conditional Windows logic.
install.sh is bash-only by design.

Acceptable if Helios only targets macOS/Linux. But the current failure mode on Windows is
cryptic Unix-command-not-found errors rather than a clear unsupported-platform message.

Recommended: Add explicit platform guard to both files:

  if (process.platform === 'win32') {
    throw new Error('Helios update requires macOS or Linux. Windows is not supported.');
  }

---

## Summary of Required Fixes

  Priority | Fix
  ---------|---------------------------------------------------------
  HIGH     | install.sh: Add .update-state.json and VERSION to all 4 PRESERVE loops
  HIGH     | update.mjs line 75: Check tar exit code; restore stash on failure
  MEDIUM   | update.mjs: Add sha256 verification before extraction
  MEDIUM   | Rebuild tarball with current extension code (./build-release.sh)
  MEDIUM   | Add VERSION to ~/.pi/agent/.gitignore
  LOW      | Add process.platform guard to update.mjs and auto-update.ts

---

## Files Reviewed
- ~/.pi/agent/extensions/auto-update.ts
- ~/.pi/agent/scripts/update.mjs
- ~/helios-team-installer/install.sh
- ~/helios-team-installer/build-release.sh
- ~/helios-team-installer/dist/VERSION
- ~/.pi/agent/.gitignore
