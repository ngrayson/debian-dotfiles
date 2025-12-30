#!/bin/bash
#
# Screensaver Launcher with Media Detection
# =========================================
#
# PURPOSE:
#   Wrapper script for the screensaver that checks for active media/microphone
#   before launching. This provides defense-in-depth - optionally, the 
#   media-idle-inhibitor.sh daemon can prevent hypridle from triggering this 
#   script when media is playing, but this check ensures we don't start 
#   screensaver even if the daemon is not running or fails.
#
# HOW IT WORKS:
#   1. Calls check-media-playing.sh to detect active media/microphone
#   2. If media is active: exits immediately (daemon should prevent this if running)
#   3. If no media: checks if screen is already locked
#   4. If not locked: launches the screensaver via omarchy-launch-screensaver
#
# NOTE:
#   Timer reset can be handled by media-idle-inhibitor.sh daemon using 
#   systemd-inhibit (when enabled). This script's media check is a safety 
#   net that works regardless of daemon status.
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
    # (Daemon should have prevented this script from running if enabled, 
    #  but this is a safety check that works regardless)
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
