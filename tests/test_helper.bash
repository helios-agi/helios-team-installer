#!/usr/bin/env bash
# Test helper - sourced by all BATS test files
export INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PI_AGENT_DIR="${BATS_TMPDIR}/mock-pi-agent"
export FAMILIAR_DIR="${BATS_TMPDIR}/mock-familiar"
export LOG_FILE="${BATS_TMPDIR}/test.log"
export HELIOS_RELEASE_URL="http://localhost:9999"
export SELECTED_PROVIDER="anthropic"
export UPDATE_MODE=false
