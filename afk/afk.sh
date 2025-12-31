#!/bin/bash
# AFK (Away From Keyboard) Application
# Toggles between AFK mode and present mode, managing hyprmon profiles,
# tmux sessions, and sleep-guard processes.

set -euo pipefail

# Configuration
LOCK_FILE="/tmp/afk-mode.lock"
TMUX_SESSION="afk"
AFK_PROFILE="afk"
PRESENT_PROFILE="Tie Fighter"
SLEEP_GUARD_CMD="sleep-guard"
LOG_FILE="${HOME}/.local/share/afk/afk.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Setup environment when launched from desktop entry
# Desktop entries don't have full shell environment
if [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    # Try to get display from systemd user session
    if command -v systemctl &> /dev/null; then
        ENV_OUTPUT=$(systemctl --user show-environment 2>/dev/null || true)
        if [[ -n "$ENV_OUTPUT" ]]; then
            DISPLAY_VAL=$(echo "$ENV_OUTPUT" | grep -E '^DISPLAY=' | cut -d= -f2- || true)
            WAYLAND_VAL=$(echo "$ENV_OUTPUT" | grep -E '^WAYLAND_DISPLAY=' | cut -d= -f2- || true)
            [[ -n "$DISPLAY_VAL" ]] && export DISPLAY="$DISPLAY_VAL" || true
            [[ -n "$WAYLAND_VAL" ]] && export WAYLAND_DISPLAY="$WAYLAND_VAL" || true
        fi
    fi
    # Try to detect from running processes
    if [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        # Check for X11
        if pgrep -x Xorg >/dev/null 2>&1 || pgrep -x Xwayland >/dev/null 2>&1; then
            export DISPLAY="${DISPLAY:-:0}"
        fi
        # Check for Wayland (common compositors)
        if pgrep -x hyprland >/dev/null 2>&1 || pgrep -x sway >/dev/null 2>&1 || pgrep -x wlroots >/dev/null 2>&1; then
            # Try to find wayland socket
            if [[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wayland-0" ]]; then
                export WAYLAND_DISPLAY="wayland-0"
            fi
        fi
    fi
fi

# Ensure PATH includes common locations
export PATH="${HOME}/bin:${HOME}/.local/bin:${PATH}"

# Ensure XDG_RUNTIME_DIR is set
[[ -z "${XDG_RUNTIME_DIR:-}" ]] && export XDG_RUNTIME_DIR="/run/user/$(id -u)" || true

# Colors for output (optional, can be removed if not needed)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log_error() {
    local msg="ERROR: $1"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') ${msg}" >> "$LOG_FILE" 2>/dev/null || true
}

log_info() {
    local msg="INFO: $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ${msg}" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    local msg="WARN: $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ${msg}" >> "$LOG_FILE" 2>/dev/null || true
}

# Function to detect terminal emulator
detect_terminal() {
    # Check environment variables first
    if [[ -n "${TERMINAL:-}" ]] && command -v "$TERMINAL" &> /dev/null; then
        echo "$TERMINAL"
        return 0
    fi
    
    if [[ -n "${TERM_PROGRAM:-}" ]] && command -v "$TERM_PROGRAM" &> /dev/null; then
        echo "$TERM_PROGRAM"
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

# Function to check if hyprmon is available
check_hyprmon() {
    if ! command -v hyprmon &> /dev/null; then
        log_error "hyprmon command not found. Please install hyprmon."
        return 1
    fi
    return 0
}

# Function to check if tmux is available
check_tmux() {
    if ! command -v tmux &> /dev/null; then
        log_error "tmux command not found. Please install tmux."
        return 1
    fi
    return 0
}

# Function to check if sleep-guard is available
check_sleep_guard() {
    # First try command -v
    if command -v "$SLEEP_GUARD_CMD" &> /dev/null; then
        return 0
    fi
    
    # Try common locations
    local common_paths=(
        "${HOME}/bin/${SLEEP_GUARD_CMD}"
        "${HOME}/.local/bin/${SLEEP_GUARD_CMD}"
        "/usr/local/bin/${SLEEP_GUARD_CMD}"
        "/usr/bin/${SLEEP_GUARD_CMD}"
        "${HOME}/Agent/sleep-guard/target/release/${SLEEP_GUARD_CMD}"
    )
    
    for path in "${common_paths[@]}"; do
        if [[ -x "$path" ]]; then
            log_info "Found sleep-guard at: $path"
            SLEEP_GUARD_CMD="$path"
            return 0
        fi
    done
    
    log_error "sleep-guard command not found. Please install sleep-guard or set SLEEP_GUARD_CMD."
    log_error "Searched in: ${common_paths[*]}"
    return 1
}

# Function to check if tmux session exists
tmux_session_exists() {
    tmux has-session -t "$TMUX_SESSION" 2>/dev/null
}

# Function to check if sleep-guard is running
sleep_guard_running() {
    pgrep -f "$SLEEP_GUARD_CMD" > /dev/null 2>&1
}

# Function to detect current mode
detect_mode() {
    # Check multiple indicators for robust detection
    local has_lock_file=false
    local has_tmux_session=false
    local has_sleep_guard=false
    
    if [[ -f "$LOCK_FILE" ]]; then
        has_lock_file=true
    fi
    
    if tmux_session_exists; then
        has_tmux_session=true
    fi
    
    if sleep_guard_running; then
        has_sleep_guard=true
    fi
    
    # If any two indicators are true, we're in AFK mode
    # This handles edge cases where one indicator might be inconsistent
    local afk_indicators=0
    [[ "$has_lock_file" == true ]] && ((afk_indicators++))
    [[ "$has_tmux_session" == true ]] && ((afk_indicators++))
    [[ "$has_sleep_guard" == true ]] && ((afk_indicators++))
    
    if [[ $afk_indicators -ge 2 ]]; then
        echo "afk"
    else
        echo "present"
    fi
}

# Function to launch terminal with tmux session
launch_terminal_with_tmux() {
    local terminal_emulator
    terminal_emulator=$(detect_terminal)
    
    if [[ -z "$terminal_emulator" ]]; then
        log_warn "No terminal emulator found. Attempting to attach directly to tmux session."
        # Try direct attach (will block if no terminal)
        tmux attach-session -t "$TMUX_SESSION" 2>/dev/null || {
            log_error "Could not attach to tmux session. Please manually attach with: tmux attach -t $TMUX_SESSION"
            return 1
        }
        return 0
    fi
    
    log_info "Launching terminal: $terminal_emulator"
    
    # Build command based on terminal type
    local cmd=""
    case "$terminal_emulator" in
        alacritty|foot|wezterm|xterm|konsole|gnome-terminal|mate-terminal|tilix)
            cmd="$terminal_emulator -e tmux attach -t $TMUX_SESSION"
            ;;
        kitty)
            cmd="$terminal_emulator tmux attach -t $TMUX_SESSION"
            ;;
        *)
            # Generic fallback
            cmd="$terminal_emulator -e tmux attach -t $TMUX_SESSION"
            ;;
    esac
    
    # Check if we're running from systemd or without display
    if [[ ! -t 1 ]] || [[ -n "${SYSTEMD_EXEC_PID:-}" ]] || ([[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]]); then
        # Launch via systemd-run in user session
        systemd-run --user \
            --setenv=DISPLAY="${DISPLAY:-}" \
            --setenv=WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
            --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
            --scope \
            sh -c "export DISPLAY=\"${DISPLAY:-}\"; export WAYLAND_DISPLAY=\"${WAYLAND_DISPLAY:-}\"; $cmd" >/dev/null 2>&1 &
    else
        # Direct launch
        eval "$cmd" >/dev/null 2>&1 &
    fi
    
    sleep 0.3  # Small delay to ensure terminal launches
}

# Function to activate AFK mode
activate_afk_mode() {
    log_info "Activating AFK mode..."
    
    # Check dependencies
    check_hyprmon || return 1
    check_tmux || return 1
    check_sleep_guard || return 1
    
    # Step 1: Switch hyprmon profile to 'afk'
    log_info "Switching hyprmon profile to '$AFK_PROFILE'..."
    if ! hyprmon -profile "$AFK_PROFILE" >> "$LOG_FILE" 2>&1; then
        log_error "Failed to switch hyprmon profile to '$AFK_PROFILE'"
        log_warn "Continuing despite profile switch failure..."
        # Don't return 1 - continue anyway
    fi
    
    # Step 2: Create tmux session 'afk' if it doesn't exist
    if ! tmux_session_exists; then
        log_info "Creating tmux session '$TMUX_SESSION'..."
        if ! tmux new-session -d -s "$TMUX_SESSION" >> "$LOG_FILE" 2>&1; then
            log_error "Failed to create tmux session '$TMUX_SESSION'"
            return 1
        fi
        sleep 0.5  # Wait for session to be ready
    else
        log_info "Tmux session '$TMUX_SESSION' already exists"
    fi
    
    # Step 3: Check if sleep-guard is already running in the session
    # If not, start it
    if ! sleep_guard_running; then
        log_info "Starting sleep-guard in tmux session..."
        # Clear any existing content and start sleep-guard
        tmux send-keys -t "$TMUX_SESSION" C-c >> "$LOG_FILE" 2>&1 || true  # Stop any running command
        sleep 0.2
        if ! tmux send-keys -t "$TMUX_SESSION" "$SLEEP_GUARD_CMD" C-m >> "$LOG_FILE" 2>&1; then
            log_error "Failed to start sleep-guard in tmux session"
            return 1
        fi
        sleep 0.5  # Wait for sleep-guard to start
    else
        log_info "sleep-guard is already running"
    fi
    
    # Step 4: Show tmux session on screen
    log_info "Launching terminal with tmux session..."
    launch_terminal_with_tmux
    
    # Step 5: Store state indicator
    echo "mode=afk" > "$LOCK_FILE"
    echo "timestamp=$(date +%s)" >> "$LOCK_FILE"
    
    log_info "AFK mode activated successfully"
    return 0
}

# Function to activate present mode
activate_present_mode() {
    log_info "Activating present mode..."
    
    # Check dependencies
    check_hyprmon || return 1
    
    # Step 1: Kill sleep-guard process
    if sleep_guard_running; then
        log_info "Stopping sleep-guard..."
        if pkill -f "$SLEEP_GUARD_CMD" 2>/dev/null; then
            sleep 0.5  # Wait for process to terminate
            # Verify it's actually killed
            if sleep_guard_running; then
                log_warn "sleep-guard still running, trying killall..."
                # killall needs just the basename, not the full path
                local sleep_guard_name=$(basename "$SLEEP_GUARD_CMD")
                killall "$sleep_guard_name" 2>/dev/null || true
                sleep 0.5
            fi
        else
            log_warn "Could not find sleep-guard process to kill (may already be stopped)"
        fi
    else
        log_info "sleep-guard is not running"
    fi
    
    # Step 2: Switch hyprmon profile to 'Tie Fighter'
    log_info "Switching hyprmon profile to '$PRESENT_PROFILE'..."
    if ! hyprmon -profile "$PRESENT_PROFILE" >> "$LOG_FILE" 2>&1; then
        log_error "Failed to switch hyprmon profile to '$PRESENT_PROFILE'"
        log_warn "Continuing despite profile switch failure..."
        # Continue anyway - profile switch failure shouldn't block mode change
    fi
    
    # Step 3: Optionally detach from tmux session (if attached)
    # This is handled automatically by the user or terminal closing
    
    # Step 4: Remove state indicator
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
    fi
    
    log_info "Present mode activated successfully"
    return 0
}

# Main function
main() {
    # Log startup
    log_info "AFK script started (PID: $$)"
    log_info "DISPLAY=${DISPLAY:-not set}, WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-not set}"
    log_info "PATH=${PATH}"
    
    local current_mode
    if ! current_mode=$(detect_mode); then
        log_error "Failed to detect current mode"
        return 1
    fi
    
    log_info "Current mode: $current_mode"
    
    if [[ "$current_mode" == "afk" ]]; then
        log_info "Switching to present mode..."
        if ! activate_present_mode; then
            log_error "Failed to activate present mode"
            return 1
        fi
    else
        log_info "Switching to AFK mode..."
        if ! activate_afk_mode; then
            log_error "Failed to activate AFK mode"
            return 1
        fi
    fi
    
    log_info "AFK script completed successfully"
    return 0
}

# Error handler
trap 'log_error "Script failed at line $LINENO. Check log: $LOG_FILE"' ERR

# Run main function
main "$@"
