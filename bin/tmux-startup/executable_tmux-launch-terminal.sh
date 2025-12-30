#!/bin/bash
# Launches a terminal window with the tmux startup session
# This script detects the terminal emulator and launches it with tmux

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
STARTUP_SCRIPT="${SCRIPT_DIR}/tmux-startup.sh"

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=config.sh
    source "$CONFIG_FILE"
fi

# Function to detect terminal emulator
detect_terminal() {
    # First, check if TERMINAL_CMD is set in config
    if [[ -n "${TERMINAL_CMD:-}" ]] && command -v "$TERMINAL_CMD" &> /dev/null; then
        echo "$TERMINAL_CMD"
        return 0
    fi
    
    # Check environment variables
    if [[ -n "${TERMINAL:-}" ]] && command -v "$TERMINAL" &> /dev/null; then
        echo "$TERMINAL"
        return 0
    fi
    
    # Try common terminal emulators in order of preference
    local terminals=(
        "alacritty"
        "kitty"
        "foot"
        "wezterm"
        "gnome-terminal"
        "konsole"
        "xterm"
        "x-terminal-emulator"
    )
    
    for term in "${terminals[@]}"; do
        if command -v "$term" &> /dev/null; then
            echo "$term"
            return 0
        fi
    done
    
    return 1
}

# Get terminal emulator
TERMINAL_EMULATOR=$(detect_terminal)

if [[ -z "$TERMINAL_EMULATOR" ]]; then
    echo "ERROR: No terminal emulator found. Please install one or set TERMINAL_CMD in config.sh" >&2
    exit 1
fi

# Get session name and workspace from config or use defaults
SESSION_NAME="${SESSION_NAME:-startup}"
WORKSPACE="${WORKSPACE:-1}"

# Ensure the tmux session exists (suppress errors if session already exists)
"$STARTUP_SCRIPT" 2>&1 | grep -v "^\[" || true

# Wait a moment for session to be ready
sleep 0.5

# Function to detect window manager/compositor
detect_wm() {
    if command -v hyprctl &> /dev/null && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        echo "hyprland"
        return 0
    elif command -v niri &> /dev/null && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        echo "niri"
        return 0
    elif command -v swaymsg &> /dev/null && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        echo "sway"
        return 0
    elif [[ -n "${DISPLAY:-}" ]] && command -v wmctrl &> /dev/null; then
        echo "x11"
        return 0
    fi
    echo "unknown"
    return 1
}

# Launch terminal with tmux attach command
# Use systemd-run to launch in user session context (needed when running from systemd service)
launch_terminal() {
    local cmd=""
    local wm=$(detect_wm)
    local workspace="${WORKSPACE:-1}"
    
    # Build the command based on terminal type
    case "$TERMINAL_EMULATOR" in
        alacritty|foot|wezterm)
            cmd="$TERMINAL_EMULATOR -e tmux attach -t $SESSION_NAME"
            ;;
        kitty)
            cmd="$TERMINAL_EMULATOR tmux attach -t $SESSION_NAME"
            ;;
        gnome-terminal|mate-terminal|tilix)
            cmd="$TERMINAL_EMULATOR -- tmux attach -t $SESSION_NAME"
            ;;
        konsole)
            cmd="$TERMINAL_EMULATOR -e tmux attach -t $SESSION_NAME"
            ;;
        xterm|uxterm|rxvt|urxvt|aterm|Eterm)
            cmd="$TERMINAL_EMULATOR -e tmux attach -t $SESSION_NAME"
            ;;
        *)
            # Generic fallback
            cmd="$TERMINAL_EMULATOR -e tmux attach -t $SESSION_NAME"
            ;;
    esac
    
    # Wrap command to launch on specific workspace based on window manager
    case "$wm" in
        hyprland)
            # Hyprland: Use [workspace X] syntax in exec command
            cmd="hyprctl dispatch exec \"[workspace $workspace] $cmd\""
            ;;
        niri)
            # Niri: Switch to workspace first, then launch
            cmd="niri msg action focus-workspace $workspace; sleep 0.1; $cmd"
            ;;
        sway)
            # Sway: Use workspace command
            cmd="swaymsg \"workspace $workspace; exec $cmd\""
            ;;
        x11)
            # X11: Use wmctrl if available, otherwise just launch
            if command -v wmctrl &> /dev/null; then
                cmd="wmctrl -s $((workspace - 1)) 2>/dev/null; $cmd"
            fi
            ;;
        *)
            # Unknown WM: Just launch normally
            ;;
    esac
    
    # Check if we're running from systemd (no TTY available)
    # When running from systemd, we need to use systemd-run to launch GUI apps
    if [[ ! -t 1 ]] || [[ -n "${SYSTEMD_EXEC_PID:-}" ]] || [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        # Launch via systemd-run in user session with proper environment
        # Use --scope to run in background, --unit to give it a name
        systemd-run --user \
            --setenv=DISPLAY="${DISPLAY:-}" \
            --setenv=WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
            --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
            --scope \
            sh -c "export DISPLAY=\"${DISPLAY:-}\"; export WAYLAND_DISPLAY=\"${WAYLAND_DISPLAY:-}\"; $cmd" >/dev/null 2>&1 &
    else
        # Direct launch (when run manually from a terminal)
        eval "$cmd" >/dev/null 2>&1 &
    fi
}

# Launch terminal
launch_terminal

# Small delay to ensure terminal launches
sleep 0.3
