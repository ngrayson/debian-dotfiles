#!/bin/bash
#
# Media Idle Inhibitor Daemon
# ===========================
#
# PURPOSE:
#   Monitors media activity and uses systemd-inhibit to prevent hypridle
#   from triggering idle actions (screensaver, lock, screen off) when
#   media is playing.
#
# HOW IT WORKS:
#   1. Polls check-media-playing.sh every 5 seconds
#   2. When media is detected: spawns systemd-inhibit --what=idle
#   3. When media stops: kills the inhibition process
#   4. Runs continuously as a background daemon
#
# USAGE:
#   Manual start: ~/.config/hypr/media-idle-inhibitor.sh &
#   Stop: kill $(cat /tmp/media-idle-inhibitor.pid) 2>/dev/null; rm -f /tmp/media-idle-inhibitor.pid
#   Check status: systemd-inhibit --list | grep "Media Idle Inhibitor"
#
# INTEGRATION:
#   - Uses: ~/.config/hypr/check-media-playing.sh
#   - Prevents: All hypridle idle actions when media is active
#   - Once verified working, can be added to autostart.conf
#

INHIBIT_PID_FILE="/tmp/media-idle-inhibitor.pid"
CHECK_SCRIPT="$HOME/.config/hypr/check-media-playing.sh"
POLL_INTERVAL=5  # Check every 5 seconds

# Cleanup function
cleanup() {
    if [ -f "$INHIBIT_PID_FILE" ]; then
        INHIBIT_PID=$(cat "$INHIBIT_PID_FILE")
        if kill -0 "$INHIBIT_PID" 2>/dev/null; then
            kill "$INHIBIT_PID" 2>/dev/null
        fi
        rm -f "$INHIBIT_PID_FILE"
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main loop
MEDIA_ACTIVE=false
while true; do
    # Check if media is playing
    if "$CHECK_SCRIPT" > /dev/null 2>&1; then
        # Media is active
        if [ "$MEDIA_ACTIVE" = false ]; then
            # Start inhibition if not already active
            if [ ! -f "$INHIBIT_PID_FILE" ] || ! kill -0 "$(cat "$INHIBIT_PID_FILE")" 2>/dev/null; then
                systemd-inhibit \
                    --what=idle \
                    --who="Media Idle Inhibitor" \
                    --why="Preventing idle actions while media is playing" \
                    --mode=block \
                    sleep infinity &
                INHIBIT_PID=$!
                echo "$INHIBIT_PID" > "$INHIBIT_PID_FILE"
                MEDIA_ACTIVE=true
            fi
        fi
    else
        # No media active
        if [ "$MEDIA_ACTIVE" = true ]; then
            # Stop inhibition
            if [ -f "$INHIBIT_PID_FILE" ]; then
                INHIBIT_PID=$(cat "$INHIBIT_PID_FILE")
                if kill -0 "$INHIBIT_PID" 2>/dev/null; then
                    kill "$INHIBIT_PID" 2>/dev/null
                fi
                rm -f "$INHIBIT_PID_FILE"
            fi
            MEDIA_ACTIVE=false
        fi
    fi
    
    sleep "$POLL_INTERVAL"
done
