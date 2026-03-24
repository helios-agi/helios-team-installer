#!/usr/bin/env bash
# manual-test.sh — Local verification of helios update flow
# Run on your Mac to test what CI can't (Docker, OrbStack, real Memgraph).
set -euo pipefail
PASS=0; FAIL=0
ok()   { echo "  ✅ $*"; ((PASS++)) || true; }
fail() { echo "  ❌ $*"; ((FAIL++)) || true; }

echo ""
echo "  Helios Update Flow — Local Test"
echo "  ═══════════════════════════════════"
echo ""

# Test 1: helios status
echo "▶ helios status"
helios status 2>&1 | grep -q "Pi CLI" && ok "helios status shows Pi CLI" || fail "helios status broken"

# Test 2: helios version
echo "▶ helios version"
VER=$(helios version 2>&1)
echo "$VER" | grep -qE '[0-9]+\.[0-9]+\.[0-9]+' && ok "helios version shows version" || fail "helios version blank"

# Test 3: installer syntax
echo "▶ installer syntax"
INSTALLER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install.sh"
bash -n "$INSTALLER" && ok "installer syntax valid" || fail "installer syntax error"

# Test 4: npm package
echo "▶ npm package check"
npm list -g @helios-agent/cli 2>/dev/null | grep -q "@helios-agent/cli" && ok "@helios-agent/cli installed" || {
  npm list -g @mariozechner/pi-coding-agent 2>/dev/null | grep -q "@mariozechner" && ok "@mariozechner installed (migration pending)" || fail "no CLI package installed"
}

# Test 5: Memgraph (if Docker available)
echo "▶ Infrastructure"
if command -v docker &>/dev/null; then
  docker ps 2>/dev/null | grep -q memgraph && ok "Memgraph running" || fail "Memgraph not running"
else
  echo "  ⚠️  Docker not available — skipping"
fi

# Summary
echo ""
echo "  ═══════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ] && echo "  ✅ All local tests passed" || { echo "  ❌ $FAIL test(s) failed"; exit 1; }
