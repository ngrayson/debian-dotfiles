#!/bin/bash
# Configuration file for tmux-startup.sh
# Modify this file to customize your tmux session layout

# Session name
SESSION_NAME="startup"

# Terminal command (empty = use default terminal)
# Examples: "alacritty", "kitty", "gnome-terminal", ""
TERMINAL_CMD=""

# Whether to attach to the session after creation
ATTACH_SESSION=true

# Command to run in the initial pane (pane 0)
# Leave empty to not run any command in the first pane
# Example: 'fastfetch', 'neofetch', 'echo "Hello"', ''
# Note: This will run in pane 0, which becomes the upper-left pane after splits
INITIAL_PANE_CMD="btop"

# Pane definitions
# Format: "pane_index split_direction size 'command'"
# - pane_index: Which pane to split (0 = initial pane)
# - split_direction: 'h' for horizontal (split left-right), 'v' for vertical (split top-bottom)
# - size: Percentage (0-100) for pane size
# - command: Command to run in the new pane (use single quotes for commands with spaces)
# Layout: btop (upper-left 40%x40%), fastfetch (bottom-left 40%x60%), stars (right 60%x100%)
PANES=(
  "0 h 99 'stars'"      # Split pane 0 horizontally at 40%: creates left (40%) and right (60%) - stars runs in right pane
  # "1 v 10 'nvim'"
  # "2 h 50 'moon'"
  "0 v 30 'clear && sleep 1 && fastfetch'"  # Split pane 0 vertically at 40%: creates top-left (40%x40%) and bottom-left (40%x60%) - fastfetch runs in bottom-left
)

# First active pane after session creation
# Specify which pane index should be active/selected when the session is created
# Default: 0 (the initial pane)
# Example: 1 (select the second pane), 2 (select the third pane), etc.
ACTIVE_PANE=1

# Workspace to launch terminal on (for window managers that support it)
# Default: 1
# Set to empty string to disable workspace targeting
WORKSPACE=1

# Behavior when session already exists
# Options: "skip", "attach", "recreate"
EXISTING_SESSION_ACTION="recreate"
