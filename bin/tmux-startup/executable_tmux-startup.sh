#!/bin/bash
# Tmux startup script - Creates a tmux session with configured panes and programs
# This script loads configuration from config.sh and creates a tmux session accordingly

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    error "tmux is not installed. Please install tmux first."
fi

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Configuration file not found: $CONFIG_FILE"
fi

# Source the configuration file
# shellcheck source=config.sh
source "$CONFIG_FILE"

# Validate configuration
if [[ -z "${SESSION_NAME:-}" ]]; then
    error "SESSION_NAME is not set in config.sh"
fi

if [[ -z "${PANES:-}" ]] || [[ ${#PANES[@]} -eq 0 ]]; then
    log "WARNING: No panes defined in config.sh. Creating session with single pane."
fi

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    log "Session '$SESSION_NAME' already exists."
    case "${EXISTING_SESSION_ACTION:-skip}" in
        "attach")
            # Only attach if we have a TTY (not running from systemd)
            if [[ -t 1 ]] && [[ -z "${SYSTEMD_EXEC_PID:-}" ]]; then
                log "Attaching to existing session..."
                if [[ -n "${TERMINAL_CMD:-}" ]]; then
                    $TERMINAL_CMD -e tmux attach-session -t "$SESSION_NAME" &
                else
                    tmux attach-session -t "$SESSION_NAME"
                fi
                exit 0
            else
                log "Session exists - terminal launcher will handle attachment"
                # Exit successfully - terminal launcher script will run next
                exit 0
            fi
            ;;
        "recreate")
            log "Recreating session '$SESSION_NAME'..."
            tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
            ;;
        "skip"|*)
            log "Skipping session creation (existing session found)."
            # If running from systemd, still let terminal launcher run
            if [[ -n "${SYSTEMD_EXEC_PID:-}" ]] || [[ ! -t 1 ]]; then
                log "Terminal launcher will attach to existing session"
                exit 0
            else
                exit 0
            fi
            ;;
    esac
fi

# Create new tmux session (detached)
log "Creating new tmux session: $SESSION_NAME"
tmux new-session -d -s "$SESSION_NAME"

# Run command in initial pane (pane 0) if configured
if [[ -n "${INITIAL_PANE_CMD:-}" ]] && [[ "${INITIAL_PANE_CMD}" != "''" ]] && [[ "${INITIAL_PANE_CMD}" != '""' ]]; then
    log "Running initial command in pane 0: $INITIAL_PANE_CMD"
    tmux send-keys -t "${SESSION_NAME}:0.0" "$INITIAL_PANE_CMD" C-m
fi

# Function to split pane and run command
split_and_run() {
    local pane_index="$1"
    local direction="$2"
    local size="$3"
    local command="$4"
    
    # Validate direction
    if [[ "$direction" != "h" ]] && [[ "$direction" != "v" ]]; then
        log "WARNING: Invalid split direction '$direction' (must be 'h' or 'v'). Skipping."
        return 1
    fi
    
    # Validate size (should be 0-100)
    if ! [[ "$size" =~ ^[0-9]+$ ]] || [[ "$size" -lt 0 ]] || [[ "$size" -gt 100 ]]; then
        log "WARNING: Invalid size '$size' (must be 0-100). Skipping."
        return 1
    fi
    
    log "Splitting pane $pane_index: direction=$direction, size=$size%, command=$command"
    
    # Split pane based on direction and capture the new pane ID using -P flag
    # Note: tmux uses -h for horizontal split (left-right) and -v for vertical split (top-bottom)
    # The -P flag prints the new pane ID to stdout
    local new_pane=""
    local split_output=""
    if [[ "$direction" == "h" ]]; then
        # Horizontal split (left-right): -h splits vertically in tmux terminology
        # Percentage: -p option specifies percentage of the window
        split_output=$(tmux split-window -h -t "${SESSION_NAME}:0.${pane_index}" -p "$size" -P -F '#{pane_index}' 2>&1)
        if [[ $? -ne 0 ]] || [[ -z "$split_output" ]]; then
            log "WARNING: Failed to split pane $pane_index horizontally. Output: $split_output"
            return 1
        fi
        new_pane=$(echo "$split_output" | head -n1 | tr -d '[:space:]')
    else
        # Vertical split (top-bottom): -v splits horizontally in tmux terminology
        split_output=$(tmux split-window -v -t "${SESSION_NAME}:0.${pane_index}" -p "$size" -P -F '#{pane_index}' 2>&1)
        if [[ $? -ne 0 ]] || [[ -z "$split_output" ]]; then
            log "WARNING: Failed to split pane $pane_index vertically. Output: $split_output"
            return 1
        fi
        new_pane=$(echo "$split_output" | head -n1 | tr -d '[:space:]')
    fi
    
    # Verify we got a valid pane ID
    if [[ -z "$new_pane" ]] || ! [[ "$new_pane" =~ ^[0-9]+$ ]]; then
        log "ERROR: Invalid pane ID returned: '$new_pane'. Skipping command."
        return 1
    fi
    
    log "New pane created: $new_pane"
    
    # Wait a moment for the pane to be fully initialized
    sleep 0.1
    
    # Verify the pane exists before trying to send commands
    if ! tmux list-panes -t "${SESSION_NAME}:0" -F '#{pane_index}' | grep -q "^${new_pane}$"; then
        log "ERROR: Pane $new_pane does not exist. Available panes: $(tmux list-panes -t "${SESSION_NAME}:0" -F '#{pane_index}' | tr '\n' ' ')"
        return 1
    fi
    
    # Run command in the new pane
    if [[ -n "$command" ]] && [[ "$command" != "''" ]] && [[ "$command" != '""' ]]; then
        log "Running command in pane $new_pane: $command"
        # Use send-keys to run the command with proper pane targeting
        # Clear any existing input first, then send the command
        # Use explicit pane targeting format: session:window.pane
        tmux send-keys -t "${SESSION_NAME}:0.${new_pane}" C-c 2>/dev/null || true
        sleep 0.1
        if ! tmux send-keys -t "${SESSION_NAME}:0.${new_pane}" "$command" C-m; then
            log "ERROR: Failed to send command '$command' to pane $new_pane"
            return 1
        fi
        log "Command sent successfully to pane $new_pane"
        # Small delay to ensure command is processed
        sleep 0.15
    else
        log "No command specified for new pane $new_pane"
    fi
    
    return 0
}

# Process each pane definition
if [[ -n "${PANES:-}" ]] && [[ ${#PANES[@]} -gt 0 ]]; then
    for pane_def in "${PANES[@]}"; do
        # Parse pane definition: "pane_index direction size 'command'"
        # Using eval to properly handle quoted commands
        eval "pane_parts=($pane_def)"
        
        if [[ ${#pane_parts[@]} -lt 3 ]]; then
            log "WARNING: Invalid pane definition: $pane_def (need at least 3 parts). Skipping."
            continue
        fi
        
        pane_index="${pane_parts[0]}"
        direction="${pane_parts[1]}"
        size="${pane_parts[2]}"
        command="${pane_parts[3]:-}"
        
        # Remove quotes from command if present
        command=$(echo "$command" | sed "s/^['\"]//;s/['\"]$//")
        
        split_and_run "$pane_index" "$direction" "$size" "$command" || true
    done
fi

# Select the configured active pane
ACTIVE_PANE="${ACTIVE_PANE:-0}"
if tmux list-panes -t "${SESSION_NAME}:0" -F '#{pane_index}' | grep -q "^${ACTIVE_PANE}$"; then
    log "Selecting pane $ACTIVE_PANE as active"
    tmux select-pane -t "${SESSION_NAME}:0.${ACTIVE_PANE}"
else
    log "WARNING: Pane $ACTIVE_PANE does not exist. Selecting pane 0 instead."
    tmux select-pane -t "${SESSION_NAME}:0.0"
fi

log "Session '$SESSION_NAME' created successfully with ${#PANES[@]} panes."

# Attach to session if requested (but not when running from systemd)
# When running from systemd, the terminal launcher script will handle attachment
if [[ "${ATTACH_SESSION:-false}" == "true" ]] && [[ -t 1 ]] && [[ -z "${SYSTEMD_EXEC_PID:-}" ]]; then
    log "Attaching to session..."
    if [[ -n "${TERMINAL_CMD:-}" ]]; then
        $TERMINAL_CMD -e tmux attach-session -t "$SESSION_NAME" &
    else
        tmux attach-session -t "$SESSION_NAME"
    fi
else
    if [[ -n "${SYSTEMD_EXEC_PID:-}" ]] || [[ ! -t 1 ]]; then
        log "Running from systemd - terminal launcher will handle attachment"
    else
        log "Session is running detached. Attach with: tmux attach -t $SESSION_NAME"
    fi
fi
