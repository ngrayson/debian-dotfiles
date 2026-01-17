#!/bin/bash
#
# hypridle-status.sh
# Diagnostic tool that reports idle state and reasons
#
# Usage:
#   hypridle-status.sh [--verbose] [--json]
#

set -euo pipefail

VERBOSE=false
JSON_OUTPUT=false

for arg in "$@"; do
    case "$arg" in
        --verbose|-v)
            VERBOSE=true
            ;;
        --json|-j)
            JSON_OUTPUT=true
            ;;
        *)
            echo "Usage: $0 [--verbose] [--json]" >&2
            exit 1
            ;;
    esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine checks directory
# If script is in ~/.local/bin/, checks are in ~/.local/bin/hypridle-checks/
# If script is in scripts/, checks are in scripts/hypridle-checks/
if [[ "$SCRIPT_DIR" == "${HOME}/.local/bin" ]] || [[ "$SCRIPT_DIR" == "/usr/local/bin" ]]; then
    CHECKS_DIR="${HOME}/.local/bin/hypridle-checks"
else
    CHECKS_DIR="${SCRIPT_DIR}/hypridle-checks"
fi

# Fallback to standard location if checks directory doesn't exist
if [[ ! -d "$CHECKS_DIR" ]]; then
    CHECKS_DIR="${HOME}/.local/bin/hypridle-checks"
fi

# Check scripts
CHECK_MEDIA="${CHECKS_DIR}/check-media-playing.sh"
CHECK_FULLSCREEN="${CHECKS_DIR}/check-fullscreen.sh"
CHECK_GAMES="${CHECKS_DIR}/check-games.sh"
CHECK_INHIBITED="${CHECKS_DIR}/check-idle-inhibited.sh"

# Run individual checks
MEDIA_STATUS="NO"
MEDIA_DETAILS=""
if [[ -x "$CHECK_MEDIA" ]]; then
    if "$CHECK_MEDIA" >/dev/null 2>&1; then
        MEDIA_STATUS="PLAYING"
        if [[ "$VERBOSE" == "true" || "$JSON_OUTPUT" == "true" ]]; then
            MEDIA_DETAILS=$("$CHECK_MEDIA" --verbose 2>&1 || echo "")
        fi
    fi
else
    MEDIA_STATUS="ERROR"
    MEDIA_DETAILS="Script not found or not executable"
fi

FULLSCREEN_STATUS="NO"
FULLSCREEN_DETAILS=""
if [[ -x "$CHECK_FULLSCREEN" ]]; then
    if "$CHECK_FULLSCREEN" >/dev/null 2>&1; then
        FULLSCREEN_STATUS="YES"
        if [[ "$VERBOSE" == "true" || "$JSON_OUTPUT" == "true" ]]; then
            FULLSCREEN_DETAILS=$("$CHECK_FULLSCREEN" --verbose 2>&1 || echo "")
        fi
    fi
else
    FULLSCREEN_STATUS="ERROR"
    FULLSCREEN_DETAILS="Script not found or not executable"
fi

GAMES_STATUS="NO"
GAMES_DETAILS=""
if [[ -x "$CHECK_GAMES" ]]; then
    if "$CHECK_GAMES" >/dev/null 2>&1; then
        GAMES_STATUS="YES"
        if [[ "$VERBOSE" == "true" || "$JSON_OUTPUT" == "true" ]]; then
            GAMES_DETAILS=$("$CHECK_GAMES" --verbose 2>&1 || echo "")
        fi
    fi
else
    GAMES_STATUS="ERROR"
    GAMES_DETAILS="Script not found or not executable"
fi

# Determine overall status
OVERALL_STATUS="WOULD_IDLE"
REASONS=()

if [[ "$MEDIA_STATUS" == "PLAYING" ]]; then
    OVERALL_STATUS="INHIBITED"
    REASONS+=("Media playback")
fi

if [[ "$FULLSCREEN_STATUS" == "YES" ]]; then
    OVERALL_STATUS="INHIBITED"
    REASONS+=("Fullscreen window")
fi

if [[ "$GAMES_STATUS" == "YES" ]]; then
    OVERALL_STATUS="INHIBITED"
    REASONS+=("Game running")
fi

# Output in requested format
if [[ "$JSON_OUTPUT" == "true" ]]; then
    # JSON output
    echo "{"
    echo "  \"status\": \"$OVERALL_STATUS\","
    echo "  \"reasons\": [$(IFS=','; echo "${REASONS[*]/#/\"}${REASONS[*]/%/\"}")],"
    echo "  \"checks\": {"
    echo "    \"media\": {"
    echo "      \"status\": \"$MEDIA_STATUS\","
    echo "      \"details\": \"$MEDIA_DETAILS\""
    echo "    },"
    echo "    \"fullscreen\": {"
    echo "      \"status\": \"$FULLSCREEN_STATUS\","
    echo "      \"details\": \"$FULLSCREEN_DETAILS\""
    echo "    },"
    echo "    \"games\": {"
    echo "      \"status\": \"$GAMES_STATUS\","
    echo "      \"details\": \"$GAMES_DETAILS\""
    echo "    }"
    echo "  }"
    echo "}"
else
    # Human-readable output
    echo "Idle Status: $OVERALL_STATUS"
    
    if [[ "$OVERALL_STATUS" == "INHIBITED" ]]; then
        echo "Reason: $(IFS=', '; echo "${REASONS[*]}")"
    fi
    
    echo ""
    echo "Details:"
    echo "  Media:     $MEDIA_STATUS"
    if [[ -n "$MEDIA_DETAILS" ]]; then
        echo "    $MEDIA_DETAILS" | sed 's/^/    /'
    fi
    
    echo "  Fullscreen: $FULLSCREEN_STATUS"
    if [[ -n "$FULLSCREEN_DETAILS" ]]; then
        echo "    $FULLSCREEN_DETAILS" | sed 's/^/    /'
    fi
    
    echo "  Games:      $GAMES_STATUS"
    if [[ -n "$GAMES_DETAILS" ]]; then
        echo "    $GAMES_DETAILS" | sed 's/^/    /'
    fi
fi

# Exit with appropriate code
if [[ "$OVERALL_STATUS" == "INHIBITED" ]]; then
    exit 0
else
    exit 1
fi
