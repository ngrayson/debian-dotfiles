#!/bin/bash
# Tmux startup script - Creates a tmux session with configured panes and programs
# This script loads configuration from config.sh and creates a tmux session accordingly

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${HOME}/.config/logon-tmux/config.jsonc"

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

# Function to detect monitors
detect_monitors() {
    local wm=$(detect_wm)
    case "$wm" in
        hyprland)
            # Get monitor info: ID|Name|X|Y
            if command -v jq &> /dev/null; then
                hyprctl monitors -j 2>/dev/null | jq -r '.[] | "\(.id)|\(.name)|\(.x)|\(.y)"' || echo ""
            else
                # Fallback: parse hyprctl output
                hyprctl monitors 2>/dev/null | grep -E "^Monitor" | while read -r line; do
                    local name=$(echo "$line" | sed -n 's/.*(\([^)]*\)).*/\1/p')
                    local id=$(hyprctl monitors -j 2>/dev/null | jq -r --arg name "$name" '.[] | select(.name == $name) | .id' || echo "")
                    local x=$(hyprctl monitors -j 2>/dev/null | jq -r --arg name "$name" '.[] | select(.name == $name) | .x' || echo "0")
                    local y=$(hyprctl monitors -j 2>/dev/null | jq -r --arg name "$name" '.[] | select(.name == $name) | .y' || echo "0")
                    echo "${id}|${name}|${x}|${y}"
                done
            fi
            ;;
        sway)
            if command -v jq &> /dev/null; then
                swaymsg -t get_outputs 2>/dev/null | jq -r '.[] | "\(.id)|\(.name)|\(.rect.x)|\(.rect.y)"' || echo ""
            else
                swaymsg -t get_outputs 2>/dev/null | grep -E "name:" | sed 's/.*name: //' | while read -r name; do
                    echo "0|${name}|0|0"
                done
            fi
            ;;
        x11)
            xrandr --listmonitors 2>/dev/null | awk 'NR>1 {print NR-2 "|" $NF "|0|0"}' || echo ""
            ;;
        *)
            # Unknown WM: assume single monitor
            echo "0|unknown|0|0"
            ;;
    esac
}

# Function to load JSONC configuration
load_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        error "Configuration file not found: $config_file"
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        error "jq is required to parse JSONC config. Please install jq."
    fi
    
    # Strip JSONC comments (// comments) and parse JSON
    # Remove // comments that appear after whitespace or at start of line
    local json_content=$(sed -E 's|^[[:space:]]*//.*||; s|[[:space:]]+//.*||' "$config_file" | jq -c . 2>/dev/null)
    if [[ -z "$json_content" ]]; then
        error "Failed to parse JSONC config file: $config_file"
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

# Determine if we're using multi-session mode
MULTI_SESSION_MODE=false
if [[ -n "${SESSIONS:-}" ]] && [[ ${#SESSIONS[@]} -gt 0 ]]; then
    MULTI_SESSION_MODE=true
    log "Multi-session mode detected: ${#SESSIONS[@]} session(s) configured"
elif [[ -n "${SESSION_NAME:-}" ]]; then
    log "Single-session mode: session '$SESSION_NAME'"
else
    error "Neither SESSIONS array nor SESSION_NAME is set in config.jsonc"
fi

# Validate single-session configuration (if not in multi-session mode)
if [[ "$MULTI_SESSION_MODE" == "false" ]]; then
    if [[ -z "${PANES:-}" ]] || [[ ${#PANES[@]} -eq 0 ]]; then
        log "WARNING: No panes defined in config.sh. Creating session with single pane."
    fi
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

# Function to parse session configuration string
# Format: "monitor:0|session:name|workspace:1|initial_cmd:cmd|active_pane:1|panes:pane1,pane2,..."
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
    SESSION_CONFIG["initial_cmd"]="${SESSION_CONFIG["initial_cmd"]:-}"
    SESSION_CONFIG["active_pane"]="${SESSION_CONFIG["active_pane"]:-0}"
    SESSION_CONFIG["panes"]="${SESSION_CONFIG["panes"]:-}"
    SESSION_CONFIG["existing_action"]="${SESSION_CONFIG["existing_action"]:-${EXISTING_SESSION_ACTION:-recreate}}"
}

# Function to create a single tmux session with its configuration
create_session() {
    local session_name="$1"
    local initial_cmd="${2:-}"
    local panes_config="${3:-}"
    local active_pane="${4:-0}"
    local existing_action="${5:-recreate}"
    
    # Check if session already exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
        log "Session '$session_name' already exists."
        case "$existing_action" in
            "attach")
                log "Session exists - will attach when terminal launches"
                return 0
                ;;
            "recreate")
                log "Recreating session '$session_name'..."
                tmux kill-session -t "$session_name" 2>/dev/null || true
                ;;
            "skip"|*)
                log "Skipping session creation (existing session found)."
                return 0
                ;;
        esac
    fi
    
    # Create new tmux session (detached)
    log "Creating new tmux session: $session_name"
    if ! tmux new-session -d -s "$session_name" 2>&1; then
        log "ERROR: Failed to create tmux session: $session_name"
        return 1
    fi
    
    # Verify the session was created
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        log "ERROR: Session '$session_name' was not created successfully"
        return 1
    fi
    
    # Run command in initial pane (pane 0) if configured
    if [[ -n "$initial_cmd" ]] && [[ "$initial_cmd" != "''" ]] && [[ "$initial_cmd" != '""' ]]; then
        log "Running initial command in pane 0: $initial_cmd"
        if ! tmux send-keys -t "${session_name}:0.0" "$initial_cmd" C-m; then
            log "WARNING: Failed to send initial command to pane 0, continuing anyway"
        fi
    fi
    
    # Note: Panes will be created after terminal attachment (handled by caller)
    # Store panes config for later use
    SESSION_PANES_CONFIG["$session_name"]="$panes_config"
    SESSION_ACTIVE_PANE["$session_name"]="$active_pane"
    
    return 0
}

# Function to create panes for a session (called after terminal attachment)
create_panes_for_session() {
    local session_name="$1"
    local panes_config="${SESSION_PANES_CONFIG["$session_name"]:-}"
    local active_pane="${SESSION_ACTIVE_PANE["$session_name"]:-0}"
    
    if [[ -z "$panes_config" ]]; then
        return 0
    fi
    
    # Parse and create panes
    # The panes_config is a comma-separated string of pane definitions
    # Each definition is: "pane_index direction size 'command'"
    # Use Python or a more robust method to split while preserving quotes
    # For now, use a simple approach: split by comma and handle each part
    
    # Convert comma-separated string to array, handling quoted commands
    # Use a Python one-liner to properly parse the comma-separated string
    if command -v python3 &> /dev/null; then
        # Use Python to split by comma while respecting quotes
        while IFS= read -r pane_def; do
            [[ -z "$pane_def" ]] && continue
            pane_def=$(echo "$pane_def" | xargs)
            [[ -z "$pane_def" ]] && continue
            
            # Parse pane definition: "pane_index direction size 'command'"
            eval "pane_parts=($pane_def)"
            
            if [[ ${#pane_parts[@]} -lt 3 ]]; then
                log "WARNING: Invalid pane definition: $pane_def (need at least 3 parts). Skipping."
                continue
            fi
            
            local pane_index="${pane_parts[0]}"
            local direction="${pane_parts[1]}"
            local size="${pane_parts[2]}"
            local command="${pane_parts[3]:-}"
            
            # Remove quotes from command if present
            command=$(echo "$command" | sed "s/^['\"]//;s/['\"]$//")
            
            # Continue even if split fails - log the error but don't exit
            if ! split_and_run "$session_name" "$pane_index" "$direction" "$size" "$command"; then
                log "WARNING: Failed to create pane from definition: $pane_def"
            fi
        done < <(python3 -c "import shlex; import sys; s=sys.stdin.read().strip(); parts=[]; current=''; in_quotes=False; quote_char=''; i=0; 
while i<len(s):
    c=s[i]
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
    i+=1
if current.strip():
    parts.append(current.strip())
for p in parts:
    print(p)" <<< "$panes_config")
    else
        # Fallback: simple comma split (may break with commands containing commas)
        IFS=',' read -ra PANE_DEFS <<< "$panes_config"
        for pane_def_raw in "${PANE_DEFS[@]}"; do
            pane_def=$(echo "$pane_def_raw" | xargs)
            [[ -z "$pane_def" ]] && continue
            
            # Parse pane definition: "pane_index direction size 'command'"
            eval "pane_parts=($pane_def)"
            
            if [[ ${#pane_parts[@]} -lt 3 ]]; then
                log "WARNING: Invalid pane definition: $pane_def (need at least 3 parts). Skipping."
                continue
            fi
            
            local pane_index="${pane_parts[0]}"
            local direction="${pane_parts[1]}"
            local size="${pane_parts[2]}"
            local command="${pane_parts[3]:-}"
            
            # Remove quotes from command if present
            command=$(echo "$command" | sed "s/^['\"]//;s/['\"]$//")
            
            # Continue even if split fails - log the error but don't exit
            if ! split_and_run "$session_name" "$pane_index" "$direction" "$size" "$command"; then
                log "WARNING: Failed to create pane from definition: $pane_def"
            fi
        done
    fi
    
    # Select the configured active pane
    if tmux list-panes -t "${session_name}:0" -F '#{pane_index}' | grep -q "^${active_pane}$"; then
        log "Selecting pane $active_pane as active for session $session_name"
        tmux select-pane -t "${session_name}:0.${active_pane}"
    else
        log "WARNING: Pane $active_pane does not exist in session $session_name. Selecting pane 0 instead."
        tmux select-pane -t "${session_name}:0.0"
    fi
    
    return 0
}

# Initialize associative arrays for storing session configs
declare -A SESSION_PANES_CONFIG
declare -A SESSION_ACTIVE_PANE

# Ensure tmux server is running by starting it if needed
# Starting a new session will start the server if it's not running
log "Ensuring tmux server is running..."
if ! tmux list-sessions &>/dev/null; then
    log "Starting tmux server..."
    # Start server by creating a temporary session, then kill it
    tmux new-session -d -s __tmux_startup_temp__ 2>/dev/null || true
    sleep 0.2
    tmux kill-session -t __tmux_startup_temp__ 2>/dev/null || true
fi

# Function to verify tmux server is running
verify_tmux_server() {
    if ! tmux list-sessions &>/dev/null; then
        log "ERROR: Tmux server is not running"
        return 1
    fi
    return 0
}

# Function to wait for a terminal client to attach to a specific session
# This ensures the window has proper dimensions before we create panes
wait_for_client_attachment() {
    local session_name="$1"
    local max_attempts="${2:-150}"  # Default: 15 seconds (150 * 0.1s), can be overridden
    
    local attempt=0
    local client_count=0
    
    log "Waiting for terminal client to attach to session '$session_name' (max ${max_attempts} attempts)..."
    
    while [[ $attempt -lt $max_attempts ]]; do
        # Check if any clients are attached to this session
        # Use || true to prevent script exit if tmux command fails
        client_count=$(tmux list-clients -t "$session_name" 2>/dev/null | wc -l || echo "0")
        
        if [[ "$client_count" =~ ^[0-9]+$ ]] && [[ "$client_count" -gt 0 ]]; then
            # Client attached, now wait for window to have valid dimensions
            local window_width=$(tmux display-message -t "${session_name}:0" -p '#{window_width}' 2>/dev/null || echo "0")
            local window_height=$(tmux display-message -t "${session_name}:0" -p '#{window_height}' 2>/dev/null || echo "0")
            
            # Check if we have valid dimensions (at least 10x10 to be safe)
            if [[ "$window_width" =~ ^[0-9]+$ ]] && [[ "$window_height" =~ ^[0-9]+$ ]] && \
               [[ "$window_width" -ge 10 ]] && [[ "$window_height" -ge 10 ]]; then
                log "Client attached and window sized for '$session_name': ${window_width}x${window_height}"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        # Show progress every 50 attempts (5 seconds)
        if [[ $((attempt % 50)) -eq 0 ]]; then
            log "Still waiting for terminal to attach to '$session_name'... (attempt $attempt/$max_attempts)"
        fi
        sleep 0.1
    done
    
    log "WARNING: No client attached to '$session_name' after $max_attempts attempts. Proceeding anyway (panes may have incorrect proportions)."
    return 1  # Return 1 to indicate timeout, but caller should continue
}

# Function to split pane and run command
split_and_run() {
    local session_name="$1"
    local pane_index="$2"
    local direction="$3"
    local size="$4"
    local command="$5"
    
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
    
    # Verify tmux server is still running and session exists before attempting split
    if ! verify_tmux_server; then
        log "ERROR: Cannot split pane - tmux server not available"
        return 1
    fi
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        log "ERROR: Cannot split pane - session '$session_name' does not exist"
        return 1
    fi
    
    # Split pane based on direction and capture the new pane ID using -P flag
    # Note: tmux uses -h for horizontal split (left-right) and -v for vertical split (top-bottom)
    # The -P flag prints the new pane ID to stdout
    local new_pane=""
    local split_output=""
    if [[ "$direction" == "h" ]]; then
        # Horizontal split (left-right): -h splits vertically in tmux terminology
        # Percentage: -p option specifies percentage of the window
        split_output=$(tmux split-window -h -t "${session_name}:0.${pane_index}" -p "$size" -P -F '#{pane_index}' 2>&1) || {
            log "WARNING: Failed to split pane $pane_index horizontally. Output: $split_output"
            return 1
        }
        if [[ -z "$split_output" ]]; then
            log "WARNING: Split command produced no output for pane $pane_index"
            return 1
        fi
        new_pane=$(echo "$split_output" | head -n1 | tr -d '[:space:]')
    else
        # Vertical split (top-bottom): -v splits horizontally in tmux terminology
        # Use -p (percentage) - this works even when window height isn't fully known yet
        split_output=$(tmux split-window -v -t "${session_name}:0.${pane_index}" -p "$size" -P -F '#{pane_index}' 2>&1) || {
            log "WARNING: Failed to split pane $pane_index vertically. Output: $split_output"
            return 1
        }
        if [[ -z "$split_output" ]]; then
            log "WARNING: Split command produced no output for pane $pane_index"
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
    if ! tmux list-panes -t "${session_name}:0" -F '#{pane_index}' | grep -q "^${new_pane}$"; then
        log "ERROR: Pane $new_pane does not exist. Available panes: $(tmux list-panes -t "${session_name}:0" -F '#{pane_index}' | tr '\n' ' ')"
        return 1
    fi
    
    # Run command in the new pane
    if [[ -n "$command" ]] && [[ "$command" != "''" ]] && [[ "$command" != '""' ]]; then
        log "Running command in pane $new_pane: $command"
        # Use send-keys to run the command with proper pane targeting
        # Clear any existing input first, then send the command
        # Use explicit pane targeting format: session:window.pane
        tmux send-keys -t "${session_name}:0.${new_pane}" C-c 2>/dev/null || true
        sleep 0.1
        if ! tmux send-keys -t "${session_name}:0.${new_pane}" "$command" C-m; then
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

# Main execution logic - handle both single and multi-session modes
if [[ "$MULTI_SESSION_MODE" == "true" ]]; then
    # Multi-session mode: create sessions for each monitor
    log "=== Multi-Session Mode ==="
    
    # Detect monitors
    MONITORS=$(detect_monitors)
    if [[ -z "$MONITORS" ]]; then
        log "WARNING: No monitors detected. Falling back to single monitor."
        MONITORS="0|unknown|0|0"
    fi
    
    # Parse monitor list into array
    declare -a MONITOR_LIST
    while IFS= read -r monitor_line; do
        [[ -n "$monitor_line" ]] && MONITOR_LIST+=("$monitor_line")
    done <<< "$MONITORS"
    
    log "Detected ${#MONITOR_LIST[@]} monitor(s)"
    
    # Process each session configuration - create sessions first
    for session_config_str in "${SESSIONS[@]}"; do
        # Parse session configuration
        parse_session_config "$session_config_str"
        
        monitor_id="${SESSION_CONFIG["monitor"]}"
        session_name="${SESSION_CONFIG["session"]}"
        workspace="${SESSION_CONFIG["workspace"]}"
        initial_cmd="${SESSION_CONFIG["initial_cmd"]}"
        active_pane="${SESSION_CONFIG["active_pane"]}"
        panes_config="${SESSION_CONFIG["panes"]}"
        existing_action="${SESSION_CONFIG["existing_action"]}"
        
        log "Processing session config: monitor=$monitor_id, session=$session_name, workspace=$workspace"
        
        # Create the session
        if create_session "$session_name" "$initial_cmd" "$panes_config" "$active_pane" "$existing_action"; then
            log "Session '$session_name' created successfully"
        else
            log "ERROR: Failed to create session '$session_name'"
        fi
        
        # Small delay between sessions
        sleep 0.1
    done
    
    log "Multi-session setup complete. Created ${#SESSIONS[@]} session(s)."
    
    # Launch terminals after all sessions are created
    if [[ -n "${SYSTEMD_EXEC_PID:-}" ]] || [[ ! -t 1 ]]; then
        log "Running from systemd - launching terminals for all sessions..."
        LAUNCHER_SCRIPT="${SCRIPT_DIR}/tmux-launch-terminal.sh"
        if [[ -f "$LAUNCHER_SCRIPT" ]]; then
            # Launch terminal launcher - it will handle attaching terminals and creating panes
            bash "$LAUNCHER_SCRIPT" >/dev/null 2>&1 &
            launcher_pid=$!
            log "Terminal launcher started (PID: $launcher_pid)"
            # Give terminals a moment to start launching, then exit
            # The terminal launcher will handle waiting for attachment and creating panes
            sleep 1
        fi
    else
        # When running manually, wait for terminals and create panes
        for session_config_str in "${SESSIONS[@]}"; do
            parse_session_config "$session_config_str"
            session_name="${SESSION_CONFIG["session"]}"
            
            log "Waiting for terminal to attach to '$session_name'..."
            wait_for_client_attachment "$session_name" || {
                log "WARNING: Timeout waiting for terminal to attach to '$session_name', proceeding with pane creation"
            }
            create_panes_for_session "$session_name"
        done
    fi
else
    # Single-session mode: backward compatibility
    log "=== Single-Session Mode ==="
    
    # When running from systemd, launch terminal first
    if [[ -n "${SYSTEMD_EXEC_PID:-}" ]] || [[ ! -t 1 ]]; then
        log "Running from systemd - launching terminal first, then waiting for attachment..."
        LAUNCHER_SCRIPT="${SCRIPT_DIR}/tmux-launch-terminal.sh"
        if [[ -f "$LAUNCHER_SCRIPT" ]]; then
            bash "$LAUNCHER_SCRIPT" >/dev/null 2>&1 &
            launcher_pid=$!
            log "Terminal launcher started (PID: $launcher_pid)"
        fi
    fi
    
    # Create single session using old logic
    # Create session without panes first, then add panes after terminal attachment
    if create_session "$SESSION_NAME" "${INITIAL_PANE_CMD:-}" "" "${ACTIVE_PANE:-0}" "${EXISTING_SESSION_ACTION:-recreate}"; then
        log "Session '$SESSION_NAME' created successfully"
        
        # Wait for terminal to attach
        wait_for_client_attachment "$SESSION_NAME"
        
        # Process pane definitions (old format) - handle PANES array directly
        if [[ -n "${PANES:-}" ]] && [[ ${#PANES[@]} -gt 0 ]]; then
            for pane_def in "${PANES[@]}"; do
                # Parse pane definition: "pane_index direction size 'command'"
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
                
                # Continue even if split fails - log the error but don't exit
                if ! split_and_run "$SESSION_NAME" "$pane_index" "$direction" "$size" "$command"; then
                    log "WARNING: Failed to create pane from definition: $pane_def"
                fi
            done
            
            # Select active pane
            ACTIVE_PANE="${ACTIVE_PANE:-0}"
            if tmux list-panes -t "${SESSION_NAME}:0" -F '#{pane_index}' | grep -q "^${ACTIVE_PANE}$"; then
                log "Selecting pane $ACTIVE_PANE as active"
                tmux select-pane -t "${SESSION_NAME}:0.${ACTIVE_PANE}"
            else
                log "WARNING: Pane $ACTIVE_PANE does not exist. Selecting pane 0 instead."
                tmux select-pane -t "${SESSION_NAME}:0.0"
            fi
        fi
        
        log "Session '$SESSION_NAME' created successfully with ${#PANES[@]} panes."
        
        # Attach to session if requested (but not when running from systemd)
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
    fi
fi
