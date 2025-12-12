#!/bin/bash
#
# Media and Microphone Activity Detection Script
# ===============================================
#
# PURPOSE:
#   Detects if media is currently playing or if the microphone is actively in use.
#   Used by hypridle to prevent screensaver activation during media playback or calls.
#
# USAGE:
#   Called by screensaver-with-media-check.sh when the screensaver timeout triggers.
#   Returns exit code 0 if media/mic is active, 1 if not.
#
# DETECTION METHODS:
#   1. Media Players: Checks playerctl for any playing media (MPV, VLC, Spotify, etc.)
#   2. Microphone Usage: Checks pactl for:
#      - Source-outputs (applications actively recording from microphone)
#      - Input sources in RUNNING state (microphones actively recording)
#   3. Fullscreen Windows: Detects fullscreen windows (often indicates video watching)
#
# TECHNICAL DETAILS:
#   - Uses 'pactl list sources short' with awk to parse tab-separated fields
#   - Only checks input sources (filters by 'input' in name) to avoid false positives
#   - Checks state column (5th field) for 'RUNNING' status
#   - Prevents false positives from output monitors or other RUNNING sources
#
# INTEGRATION:
#   - Called by: ~/.config/hypr/screensaver-with-media-check.sh
#   - Used by: hypridle listener timeout (150s / 2.5min)
#   - Prevents: Screensaver activation when media/mic is active
#

# Check playerctl for media players
if command -v playerctl > /dev/null; then
    if playerctl status 2>/dev/null | grep -q "Playing"; then
        echo "MEDIA"
        exit 0  # Media is playing
    fi
fi

# Check if microphone is active (indicates calls/meetings)
if command -v pactl > /dev/null; then
    # Check for source-outputs (applications recording from microphone)
    # If there are any source-outputs, something is using the mic
    source_outputs=$(pactl list source-outputs short 2>/dev/null | wc -l)
    if [ "$source_outputs" -gt 0 ]; then
        echo "SOURCE_OUTPUT"
        exit 0  # Microphone is in use
    fi
    
    # Check each input source individually to see if it's RUNNING
    # Parse pactl list sources short line by line, checking state column (5th field)
    # Use awk to check if any input source has RUNNING state
    if pactl list sources short 2>/dev/null | awk -F'\t' '$2 ~ /input/ && $5 == "RUNNING" {found=1} END {if(found) exit 0; exit 1}'; then
        echo "MIC_RUNNING"
        exit 0  # Microphone source is actively recording
    fi
fi

# Check for fullscreen windows (often indicates video watching)
if hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.fullscreen == true)' | grep -q "."; then
    echo "FULLSCREEN"
    exit 0  # Fullscreen window detected
fi

exit 1  # No media/mic activity detected
