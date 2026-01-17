#!/bin/bash
#
# check-media-playing.sh
# Checks if any media is currently playing via MPRIS (Media Player Remote Interfacing Specification)
#
# Exit codes:
#   0 - Media is playing
#   1 - No media playing
#   2 - Error (D-Bus unavailable, etc.)
#
# Usage:
#   check-media-playing.sh [--verbose]
#

set -euo pipefail

VERBOSE=false
if [[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]]; then
    VERBOSE=true
fi

# Check if D-Bus session is available
if ! command -v dbus-send &> /dev/null; then
    if [[ "$VERBOSE" == "true" ]]; then
        echo "Error: dbus-send not found" >&2
    fi
    exit 2
fi

# Get list of MPRIS players
# Query org.mpris.MediaPlayer2 service names
PLAYERS=$(dbus-send --session --print-reply --dest=org.freedesktop.DBus \
    /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null | \
    grep -oP 'org\.mpris\.MediaPlayer2\.[^"]+' || true)

if [[ -z "$PLAYERS" ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
        echo "No MPRIS players found"
    fi
    exit 1
fi

# Check each player for playback status
PLAYING_PLAYER=""
PLAYING_TITLE=""

for PLAYER in $PLAYERS; do
    # Get playback status
    STATUS=$(dbus-send --session --print-reply --dest="$PLAYER" \
        /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get \
        string:org.mpris.MediaPlayer2.Player string:PlaybackStatus 2>/dev/null | \
        grep -oP 'string\s+"\K[^"]+' || echo "")

    if [[ "$STATUS" == "Playing" ]]; then
        PLAYING_PLAYER="$PLAYER"
        
        # Try to get track title/metadata for verbose output
        if [[ "$VERBOSE" == "true" ]]; then
            METADATA=$(dbus-send --session --print-reply --dest="$PLAYER" \
                /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get \
                string:org.mpris.MediaPlayer2.Player string:Metadata 2>/dev/null || true)
            
            # Extract title from metadata (simplified - may need more robust parsing)
            TITLE=$(echo "$METADATA" | grep -oP 'xesam:title.*?string\s+"\K[^"]+' | head -1 || echo "")
            ARTIST=$(echo "$METADATA" | grep -oP 'xesam:artist.*?string\s+"\K[^"]+' | head -1 || echo "")
            
            if [[ -n "$TITLE" ]]; then
                if [[ -n "$ARTIST" ]]; then
                    PLAYING_TITLE="$ARTIST - $TITLE"
                else
                    PLAYING_TITLE="$TITLE"
                fi
            fi
        fi
        
        break
    fi
done

if [[ -n "$PLAYING_PLAYER" ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
        # Clean up player name (remove org.mpris.MediaPlayer2. prefix)
        PLAYER_NAME="${PLAYING_PLAYER#org.mpris.MediaPlayer2.}"
        if [[ -n "$PLAYING_TITLE" ]]; then
            echo "Media playing: $PLAYER_NAME - $PLAYING_TITLE"
        else
            echo "Media playing: $PLAYER_NAME"
        fi
    fi
    exit 0
else
    if [[ "$VERBOSE" == "true" ]]; then
        echo "No media playing"
    fi
    exit 1
fi
