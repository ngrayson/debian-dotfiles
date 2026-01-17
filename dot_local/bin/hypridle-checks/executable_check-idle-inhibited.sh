#!/bin/bash
#
# check-idle-inhibited.sh
# Master script that checks all conditions that should prevent idle actions
# Returns 0 if idle should be inhibited, non-zero if idle can proceed
#
# Exit codes:
#   0 - Idle should be inhibited (media/fullscreen/games active)
#   1 - Idle can proceed (no inhibiting conditions)
#   2 - Error in script execution
#
# Usage:
#   check-idle-inhibited.sh [--verbose]
#

set -euo pipefail

VERBOSE=false
if [[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]]; then
    VERBOSE=true
fi

# Get script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check scripts
CHECK_MEDIA="${SCRIPT_DIR}/check-media-playing.sh"
CHECK_FULLSCREEN="${SCRIPT_DIR}/check-fullscreen.sh"
CHECK_GAMES="${SCRIPT_DIR}/check-games.sh"

# Track which conditions are active
MEDIA_ACTIVE=false
FULLSCREEN_ACTIVE=false
GAMES_ACTIVE=false
REASONS=()

# Check media playback
if [[ -x "$CHECK_MEDIA" ]]; then
    if "$CHECK_MEDIA" >/dev/null 2>&1; then
        MEDIA_ACTIVE=true
        if [[ "$VERBOSE" == "true" ]]; then
            MEDIA_INFO=$("$CHECK_MEDIA" --verbose 2>&1 || true)
            REASONS+=("Media: $MEDIA_INFO")
        else
            REASONS+=("Media playing")
        fi
    fi
else
    if [[ "$VERBOSE" == "true" ]]; then
        echo "Warning: check-media-playing.sh not found or not executable" >&2
    fi
fi

# Check fullscreen windows
if [[ -x "$CHECK_FULLSCREEN" ]]; then
    if "$CHECK_FULLSCREEN" >/dev/null 2>&1; then
        FULLSCREEN_ACTIVE=true
        if [[ "$VERBOSE" == "true" ]]; then
            FULLSCREEN_INFO=$("$CHECK_FULLSCREEN" --verbose 2>&1 || true)
            REASONS+=("Fullscreen: $FULLSCREEN_INFO")
        else
            REASONS+=("Fullscreen window")
        fi
    fi
else
    if [[ "$VERBOSE" == "true" ]]; then
        echo "Warning: check-fullscreen.sh not found or not executable" >&2
    fi
fi

# Check games
if [[ -x "$CHECK_GAMES" ]]; then
    if "$CHECK_GAMES" >/dev/null 2>&1; then
        GAMES_ACTIVE=true
        if [[ "$VERBOSE" == "true" ]]; then
            GAMES_INFO=$("$CHECK_GAMES" --verbose 2>&1 || true)
            REASONS+=("Games: $GAMES_INFO")
        else
            REASONS+=("Game running")
        fi
    fi
else
    if [[ "$VERBOSE" == "true" ]]; then
        echo "Warning: check-games.sh not found or not executable" >&2
    fi
fi

# If any condition is active, inhibit idle
if [[ "$MEDIA_ACTIVE" == "true" || "$FULLSCREEN_ACTIVE" == "true" || "$GAMES_ACTIVE" == "true" ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
        echo "Idle inhibited. Reasons:"
        for REASON in "${REASONS[@]}"; do
            echo "  - $REASON"
        done
    fi
    exit 0
else
    if [[ "$VERBOSE" == "true" ]]; then
        echo "Idle not inhibited (no active conditions)"
    fi
    exit 1
fi
