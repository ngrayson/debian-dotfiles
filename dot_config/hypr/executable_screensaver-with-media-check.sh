#!/bin/bash
#
# Screensaver Launcher with Media Detection
# =========================================
#
# PURPOSE:
#   Wrapper script for the screensaver that checks for active media/microphone
#   before launching. If media is detected, the script exits without starting
#   the screensaver, effectively resetting the screensaver timer.
#
# HOW IT WORKS:
#   1. Calls check-media-playing.sh to detect active media/microphone
#   2. If media is active: exits immediately (screensaver timer resets)
#   3. If no media: checks if screen is already locked
#   4. If not locked: launches the screensaver via omarchy-launch-screensaver
#
# TIMER RESET BEHAVIOR:
#   When media is detected, exiting without starting the screensaver causes
#   hypridle to restart the timeout countdown from 0. This means the screensaver
#   will only activate after 2.5 minutes of idle time WITH no media activity.
#
# INTEGRATION:
#   - Called by: hypridle listener (timeout = 150s / 2.5min)
#   - Uses: ~/.config/hypr/check-media-playing.sh for detection
#   - Launches: omarchy-launch-screensaver when appropriate
#   - Prevents: Screensaver during YouTube, Google Meet, Zoom, etc.
#

# Check if media is playing
if ~/.config/hypr/check-media-playing.sh; then
    # Media is playing - exit without starting screensaver
    # This effectively resets/reskips the screensaver timer
    exit 0
fi

# No media playing - proceed with screensaver
if pidof hyprlock > /dev/null; then
    # Already locked, don't start screensaver
    exit 0
else
    # Start screensaver
    omarchy-launch-screensaver
fi
