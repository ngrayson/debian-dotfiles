#!/bin/bash
#
# check-fullscreen.sh
# Checks if any window is currently in fullscreen mode using hyprctl
#
# Exit codes:
#   0 - Fullscreen window detected
#   1 - No fullscreen window
#   2 - Error (hyprctl unavailable, etc.)
#
# Usage:
#   check-fullscreen.sh [--verbose]
#

set -euo pipefail

VERBOSE=false
if [[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]]; then
    VERBOSE=true
fi

# Check if hyprctl is available
if ! command -v hyprctl &> /dev/null; then
    if [[ "$VERBOSE" == "true" ]]; then
        echo "Error: hyprctl not found" >&2
    fi
    exit 2
fi

# Check if jq is available for JSON parsing (preferred)
USE_JQ=false
if command -v jq &> /dev/null; then
    USE_JQ=true
fi

# Get client list
if [[ "$USE_JQ" == "true" ]]; then
    # Use jq for robust JSON parsing
    FULLSCREEN_CLIENTS=$(hyprctl clients -j 2>/dev/null | \
        jq -r '.[] | select(.fullscreen == true) | "\(.class)|\(.title)"' || true)
else
    # Fallback to grep parsing (less robust but works without jq)
    FULLSCREEN_CLIENTS=$(hyprctl clients 2>/dev/null | \
        grep -B 10 'fullscreen: 1' | \
        grep -E '^(class|title):' | \
        paste - - | \
        sed 's/class: //;s/\ttitle: /|/' || true)
fi

if [[ -z "$FULLSCREEN_CLIENTS" ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
        echo "No fullscreen windows"
    fi
    exit 1
fi

# Found at least one fullscreen window
if [[ "$VERBOSE" == "true" ]]; then
    # Show first fullscreen window found
    FIRST_CLIENT=$(echo "$FULLSCREEN_CLIENTS" | head -1)
    CLASS=$(echo "$FIRST_CLIENT" | cut -d'|' -f1)
    TITLE=$(echo "$FIRST_CLIENT" | cut -d'|' -f2-)
    
    if [[ -n "$TITLE" && "$TITLE" != "$CLASS" ]]; then
        echo "Fullscreen window: $CLASS - $TITLE"
    else
        echo "Fullscreen window: $CLASS"
    fi
fi

exit 0
