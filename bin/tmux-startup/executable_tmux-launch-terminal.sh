#!/bin/bash
# Launches a terminal window with the tmux startup session
# This script detects the terminal emulator and launches it with tmux

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${HOME}/.config/logon-tmux/config.jsonc"
STARTUP_SCRIPT="${SCRIPT_DIR}/tmux-startup.sh"

# Function to load JSONC configuration
load_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "WARNING: Configuration file not found: $config_file" >&2
        return 1
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "ERROR: jq is required to parse JSONC config. Please install jq." >&2
        return 1
    fi
    
    # Strip JSONC comments (// comments) and parse JSON
    # Remove // comments that appear after whitespace or at start of line
    local json_content=$(sed -E 's|^[[:space:]]*//.*||; s|[[:space:]]+//.*||' "$config_file" | jq -c . 2>/dev/null)
    if [[ -z "$json_content" ]]; then
        echo "ERROR: Failed to parse JSONC config file: $config_file" >&2
        return 1
    fi
    
    # Load terminal_cmd
    TERMINAL_CMD=$(echo "$json_content" | jq -r '.terminal_cmd // ""')
    
    # Load single-session config
    SESSION_NAME=$(echo "$json_content" | jq -r '.single_session.session_name // "startup"')
    ATTACH_SESSION=$(echo "$json_content" | jq -r '.single_session.attach_session // true')
    INITIAL_PANE_CMD=$(echo "$json_content" | jq -r '.single_session.initial_pane_cmd // ""')
    ACTIVE_PANE=$(echo "$json_content" | jq -r '.single_session.active_pane // 0')
    WORKSPACE=$(echo "$json_content" | jq -r '.single_session.workspace // 1')
    EXISTING_SESSION_ACTION=$(echo "$json_content" | jq -r '.single_session.existing_action // "recreate"')
    
    # Load PANES array for single-session mode
    PANES=()
    local panes_count=$(echo "$json_content" | jq -r '.single_session.panes | length')
    for ((i=0; i<panes_count; i++)); do
        PANES+=("$(echo "$json_content" | jq -r ".single_session.panes[$i]")")
    done
    
    # Load multi-session config
    SESSIONS=()
    local sessions_count=$(echo "$json_content" | jq -r '.sessions | length')
    for ((i=0; i<sessions_count; i++)); do
        local monitor=$(echo "$json_content" | jq -r ".sessions[$i].monitor")
        local session=$(echo "$json_content" | jq -r ".sessions[$i].session")
        local workspace=$(echo "$json_content" | jq -r ".sessions[$i].workspace")
        local initial_cmd=$(echo "$json_content" | jq -r ".sessions[$i].initial_cmd")
        local active_pane=$(echo "$json_content" | jq -r ".sessions[$i].active_pane")
        local existing_action=$(echo "$json_content" | jq -r ".sessions[$i].existing_action")
        
        # Build panes string
        local panes_str=""
        local panes_array=$(echo "$json_content" | jq -c ".sessions[$i].panes")
        local panes_len=$(echo "$panes_array" | jq 'length')
        for ((j=0; j<panes_len; j++)); do
            local pane=$(echo "$panes_array" | jq -r ".[$j]")
            if [[ -n "$panes_str" ]]; then
                panes_str="${panes_str},"
            fi
            panes_str="${panes_str}${pane}"
        done
        
        # Build session config string in the format: "monitor:ID|session:NAME|workspace:WS|initial_cmd:CMD|active_pane:N|panes:PANE1,PANE2,...|existing_action:ACTION"
        local session_config="monitor:${monitor}|session:${session}|workspace:${workspace}|initial_cmd:${initial_cmd}|active_pane:${active_pane}|panes:${panes_str}|existing_action:${existing_action}"
        SESSIONS+=("$session_config")
    done
}

# Load configuration
load_config "$CONFIG_FILE"

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

# Determine if we're using multi-session mode
MULTI_SESSION_MODE=false
if [[ -n "${SESSIONS:-}" ]] && [[ ${#SESSIONS[@]} -gt 0 ]]; then
    MULTI_SESSION_MODE=true
fi

# Function to parse session configuration string
parse_session_config() {
    local config_str="$1"
    declare -gA SESSION_CONFIG
    
    # Split by | and parse each key:value pair
    IFS='|' read -ra PARTS <<< "$config_str"
    for part in "${PARTS[@]}"; do
        local key="${part%%:*}"
        local value="${part#*:}"
        SESSION_CONFIG["$key"]="$value"
    done
    
    # Set defaults
    SESSION_CONFIG["monitor"]="${SESSION_CONFIG["monitor"]:-0}"
    SESSION_CONFIG["session"]="${SESSION_CONFIG["session"]:-startup-monitor-${SESSION_CONFIG["monitor"]}}"
    SESSION_CONFIG["workspace"]="${SESSION_CONFIG["workspace"]:-1}"
}

# Wait a moment for sessions to be ready
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

# Function to get monitor name from monitor ID (for Hyprland)
get_monitor_name() {
    local monitor_id="$1"
    local wm=$(detect_wm)
    
    if [[ "$wm" != "hyprland" ]]; then
        echo "$monitor_id"
        return 0
    fi
    
    if command -v jq &> /dev/null && command -v hyprctl &> /dev/null; then
        local monitor_name=$(hyprctl monitors -j 2>/dev/null | jq -r --arg id "$monitor_id" '.[] | select(.id == ($id | tonumber)) | .name' 2>/dev/null)
        if [[ -n "$monitor_name" ]] && [[ "$monitor_name" != "null" ]]; then
            echo "$monitor_name"
            return 0
        fi
    fi
    
    # Fallback: return ID if we can't get name
    echo "$monitor_id"
    return 1
}

# Launch terminal with tmux attach command for a specific session
# Use systemd-run to launch in user session context (needed when running from systemd service)
launch_terminal() {
    local session_name="$1"
    local workspace="${2:-1}"
    local monitor_id="${3:-}"
    
    # Verify session exists
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "WARNING: Session '$session_name' does not exist. Skipping terminal launch." >&2
        return 1
    fi
    
    local cmd=""
    local wm=$(detect_wm)
    
    # Build the command based on terminal type
    case "$TERMINAL_EMULATOR" in
        alacritty|foot|wezterm)
            cmd="$TERMINAL_EMULATOR -e tmux attach -t $session_name"
            ;;
        kitty)
            cmd="$TERMINAL_EMULATOR tmux attach -t $session_name"
            ;;
        gnome-terminal|mate-terminal|tilix)
            cmd="$TERMINAL_EMULATOR -- tmux attach -t $session_name"
            ;;
        konsole)
            cmd="$TERMINAL_EMULATOR -e tmux attach -t $session_name"
            ;;
        xterm|uxterm|rxvt|urxvt|aterm|Eterm)
            cmd="$TERMINAL_EMULATOR -e tmux attach -t $session_name"
            ;;
        *)
            # Generic fallback
            cmd="$TERMINAL_EMULATOR -e tmux attach -t $session_name"
            ;;
    esac
    
    # Wrap command to launch on specific workspace/monitor based on window manager
    if [[ -n "$workspace" ]] && [[ "$workspace" != "0" ]]; then
        case "$wm" in
            hyprland)
                # Hyprland: First move workspace to monitor, then launch on that workspace
                if [[ -n "$monitor_id" ]]; then
                    # Get monitor name from ID (Hyprland requires names for moveworkspacetomonitor)
                    local monitor_name=$(get_monitor_name "$monitor_id")
                    # Move workspace to monitor, then launch on that workspace
                    cmd="hyprctl dispatch moveworkspacetomonitor '$workspace $monitor_name' 2>/dev/null; sleep 0.5; hyprctl dispatch exec '[workspace $workspace] $cmd'"
                else
                    cmd="hyprctl dispatch exec '[workspace $workspace] $cmd'"
                fi
                ;;
            niri)
                # Niri: Switch to workspace first, then launch
                cmd="niri msg action focus-workspace $workspace; sleep 0.2; $cmd"
                ;;
            sway)
                # Sway: Use workspace command
                cmd="swaymsg workspace $workspace; swaymsg exec '$cmd'"
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
    elif [[ -n "$monitor_id" ]] && [[ "$wm" == "hyprland" ]]; then
        # If only monitor specified (no workspace), get monitor name and target directly
        local monitor_name=$(get_monitor_name "$monitor_id")
        cmd="hyprctl dispatch exec '[monitor:$monitor_name] $cmd'"
    fi
    
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

# Function to wait for session to exist
wait_for_session() {
    local session_name="$1"
    local max_attempts=50
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if tmux has-session -t "$session_name" 2>/dev/null; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    return 1
}

# Function to wait for terminal attachment and create panes
wait_and_create_panes() {
    local session_name="$1"
    local panes_config="$2"
    local active_pane="$3"
    
    # Wait for terminal to attach (up to 15 seconds)
    local attempt=0
    local max_attempts=150
    local client_count=0
    
    echo "Waiting for terminal to attach to '$session_name'..." >&2
    while [[ $attempt -lt $max_attempts ]]; do
        client_count=$(tmux list-clients -t "$session_name" 2>/dev/null | wc -l || echo "0")
        if [[ "$client_count" =~ ^[0-9]+$ ]] && [[ "$client_count" -gt 0 ]]; then
            local window_width=$(tmux display-message -t "${session_name}:0" -p '#{window_width}' 2>/dev/null || echo "0")
            local window_height=$(tmux display-message -t "${session_name}:0" -p '#{window_height}' 2>/dev/null || echo "0")
            if [[ "$window_width" =~ ^[0-9]+$ ]] && [[ "$window_height" =~ ^[0-9]+$ ]] && \
               [[ "$window_width" -ge 10 ]] && [[ "$window_height" -ge 10 ]]; then
                echo "Terminal attached to '$session_name': ${window_width}x${window_height}" >&2
                break
            fi
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    
    # Create panes using the startup script's function (if available) or directly
    if [[ -n "$panes_config" ]]; then
        echo "Creating panes for '$session_name'..." >&2
        # Source the startup script to get create_panes_for_session function
        STARTUP_SCRIPT="${SCRIPT_DIR}/tmux-startup.sh"
        if [[ -f "$STARTUP_SCRIPT" ]]; then
            # Extract and run pane creation logic
            # For now, we'll create panes directly here
            # Parse panes config and create panes
            if command -v python3 &> /dev/null; then
                while IFS= read -r pane_def; do
                    [[ -z "$pane_def" ]] && continue
                    pane_def=$(echo "$pane_def" | xargs)
                    [[ -z "$pane_def" ]] && continue
                    
                    # Parse pane definition more carefully to handle && and other special chars
                    # Format: "pane_index direction size 'command'"
                    # Extract parts using a more robust method
                    pane_index=$(echo "$pane_def" | awk '{print $1}')
                    direction=$(echo "$pane_def" | awk '{print $2}')
                    size=$(echo "$pane_def" | awk '{print $3}')
                    
                    # Extract command (everything after the third space, removing quotes)
                    command=$(echo "$pane_def" | sed "s/^[^ ]* [^ ]* [^ ]* //" | sed "s/^['\"]//;s/['\"]$//")
                    
                    if [[ -z "$pane_index" ]] || [[ -z "$direction" ]] || [[ -z "$size" ]]; then
                        echo "WARNING: Invalid pane definition: $pane_def" >&2
                        continue
                    fi
                    
                    # Split pane and capture the new pane index using -P flag
                    local new_pane=""
                    local split_output=""
                    if [[ "$direction" == "h" ]]; then
                        split_output=$(tmux split-window -h -t "${session_name}:0.${pane_index}" -p "$size" -P -F '#{pane_index}' 2>&1) || {
                            echo "WARNING: Failed to split pane $pane_index horizontally. Output: $split_output" >&2
                            continue
                        }
                        if [[ -z "$split_output" ]]; then
                            echo "WARNING: Split command produced no output for pane $pane_index" >&2
                            continue
                        fi
                        new_pane=$(echo "$split_output" | head -n1 | tr -d '[:space:]')
                    else
                        split_output=$(tmux split-window -v -t "${session_name}:0.${pane_index}" -p "$size" -P -F '#{pane_index}' 2>&1) || {
                            echo "WARNING: Failed to split pane $pane_index vertically. Output: $split_output" >&2
                            continue
                        }
                        if [[ -z "$split_output" ]]; then
                            echo "WARNING: Split command produced no output for pane $pane_index" >&2
                            continue
                        fi
                        new_pane=$(echo "$split_output" | head -n1 | tr -d '[:space:]')
                    fi
                    
                    # Verify we got a valid pane ID
                    if [[ -z "$new_pane" ]] || ! [[ "$new_pane" =~ ^[0-9]+$ ]]; then
                        echo "WARNING: Invalid pane ID returned: '$new_pane'. Skipping command." >&2
                        continue
                    fi
                    
                    # Run command if specified
                    if [[ -n "$command" ]] && [[ "$command" != "''" ]] && [[ "$command" != '""' ]]; then
                        sleep 0.1
                        # Verify the pane exists before trying to send commands
                        if tmux list-panes -t "${session_name}:0" -F '#{pane_index}' | grep -q "^${new_pane}$"; then
                            tmux send-keys -t "${session_name}:0.${new_pane}" C-c 2>/dev/null || true
                            sleep 0.1
                            tmux send-keys -t "${session_name}:0.${new_pane}" "$command" C-m 2>/dev/null || {
                                echo "WARNING: Failed to send command to pane $new_pane" >&2
                            }
                        else
                            echo "WARNING: Pane $new_pane does not exist. Available panes: $(tmux list-panes -t "${session_name}:0" -F '#{pane_index}' | tr '\n' ' ')" >&2
                        fi
                    fi
                done < <(python3 -c "
import sys
s=sys.stdin.read().strip()
if not s:
    sys.exit(0)
parts=[]
current=''
in_quotes=False
quote_char=''
for c in s:
    if c in [\"'\", '\"']:
        if not in_quotes:
            in_quotes=True
            quote_char=c
        elif quote_char==c:
            in_quotes=False
            quote_char=''
        current+=c
    elif c==',' and not in_quotes:
        if current.strip():
            parts.append(current.strip())
        current=''
    else:
        current+=c
if current.strip():
    parts.append(current.strip())
for p in parts:
    print(p)
" <<< "$panes_config")
            fi
        fi
        
        # Select active pane
        if tmux list-panes -t "${session_name}:0" -F '#{pane_index}' | grep -q "^${active_pane}$"; then
            tmux select-pane -t "${session_name}:0.${active_pane}"
        fi
    fi
}

# Launch terminals based on mode
if [[ "$MULTI_SESSION_MODE" == "true" ]]; then
    # Multi-session mode: launch terminal for each session
    echo "Launching terminals for ${#SESSIONS[@]} session(s)..." >&2
    
    for session_config_str in "${SESSIONS[@]}"; do
        # Parse session configuration
        parse_session_config "$session_config_str"
        
        session_name="${SESSION_CONFIG["session"]}"
        workspace="${SESSION_CONFIG["workspace"]}"
        monitor_id="${SESSION_CONFIG["monitor"]}"
        panes_config="${SESSION_CONFIG["panes"]}"
        active_pane="${SESSION_CONFIG["active_pane"]}"
        
        # Wait for session to exist (startup script creates it)
        if wait_for_session "$session_name"; then
            echo "Session '$session_name' exists, launching terminal..." >&2
            launch_terminal "$session_name" "$workspace" "$monitor_id"
            
            # Wait for terminal and create panes in background
            (wait_and_create_panes "$session_name" "$panes_config" "$active_pane") &
        else
            echo "WARNING: Session '$session_name' does not exist after waiting. Skipping." >&2
        fi
        
        # Small delay between launches
        sleep 0.5
    done
    
    # Wait for all background pane creation processes
    wait
else
    # Single-session mode: backward compatibility
    SESSION_NAME="${SESSION_NAME:-startup}"
    WORKSPACE="${WORKSPACE:-1}"
    
    # Wait for session to exist
    if wait_for_session "$SESSION_NAME"; then
        launch_terminal "$SESSION_NAME" "$WORKSPACE"
    else
        echo "WARNING: Session '$SESSION_NAME' does not exist after waiting." >&2
    fi
fi

# Small delay to ensure terminals launch
sleep 0.5
