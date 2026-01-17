#!/bin/bash
#
# check-games.sh
# Checks if any games are currently running by matching window classes
#
# Exit codes:
#   0 - Game detected
#   1 - No game detected
#   2 - Error (hyprctl unavailable, etc.)
#
# Usage:
#   check-games.sh [--verbose]
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

# Game window class patterns to match
# These patterns are matched case-insensitively
GAME_PATTERNS=(
    "steam_app_"
    "steam_proton_"
    "steamwebhelper"
    "lutris"
    "heroic"
    "game"
    "unity"
    "unreal"
    "godot"
    "rpg"
    "wine"
    "proton"
    # Add more patterns as needed
)

# Build regex pattern (case-insensitive)
PATTERN=$(IFS='|'; echo "${GAME_PATTERNS[*]}")
PATTERN_LOWER=$(echo "$PATTERN" | tr '[:upper:]' '[:lower:]')

# Get client list
if [[ "$USE_JQ" == "true" ]]; then
    # Use jq for robust JSON parsing
    GAME_CLIENTS=$(hyprctl clients -j 2>/dev/null | \
        jq -r --arg pattern "$PATTERN_LOWER" \
        '.[] | select(.class | ascii_downcase | test($pattern)) | "\(.class)|\(.title)"' || true)
else
    # Fallback to grep parsing
    GAME_CLIENTS=$(hyprctl clients 2>/dev/null | \
        grep -iE "class:.*($PATTERN)" | \
        sed 's/class: //' | \
        while read -r CLASS; do
            # Try to get title for this class
            TITLE=$(hyprctl clients 2>/dev/null | \
                grep -A 5 "class: $CLASS" | \
                grep "title:" | \
                head -1 | \
                sed 's/title: //' || echo "")
            echo "${CLASS}|${TITLE}"
        done || true)
fi

# Filter out false positives (Steam itself, launchers when no game is running)
# Steam client itself should not be considered a game
FILTERED_CLIENTS=""
if [[ -n "$GAME_CLIENTS" ]]; then
    while IFS= read -r CLIENT; do
        CLASS=$(echo "$CLIENT" | cut -d'|' -f1 | tr '[:upper:]' '[:lower:]')
        
        # Skip Steam client itself (not steam_app_*)
        if [[ "$CLASS" == "steam" ]]; then
            continue
        fi
        
        # Skip Lutris launcher itself (not actual games)
        if [[ "$CLASS" == "lutris" ]]; then
            continue
        fi
        
        # Include this client
        if [[ -z "$FILTERED_CLIENTS" ]]; then
            FILTERED_CLIENTS="$CLIENT"
        else
            FILTERED_CLIENTS="$FILTERED_CLIENTS"$'\n'"$CLIENT"
        fi
    done <<< "$GAME_CLIENTS"
fi

if [[ -z "$FILTERED_CLIENTS" ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
        echo "No games detected"
    fi
    exit 1
fi

# Found at least one game
if [[ "$VERBOSE" == "true" ]]; then
    # Show first game found
    FIRST_GAME=$(echo "$FILTERED_CLIENTS" | head -1)
    CLASS=$(echo "$FIRST_GAME" | cut -d'|' -f1)
    TITLE=$(echo "$FIRST_GAME" | cut -d'|' -f2-)
    
    if [[ -n "$TITLE" && "$TITLE" != "$CLASS" ]]; then
        echo "Game detected: $CLASS - $TITLE"
    else
        echo "Game detected: $CLASS"
    fi
fi

exit 0
