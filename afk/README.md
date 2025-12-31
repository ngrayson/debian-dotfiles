# AFK (Away From Keyboard) Application

A lightweight application that toggles between AFK mode and present mode, managing hyprmon profiles, tmux sessions, and sleep-guard processes.

## Description

The AFK application provides a simple way to switch between two system states:
- **AFK Mode**: Activates the 'afk' hyprmon profile, creates a tmux session, and starts sleep-guard
- **Present Mode**: Deactivates sleep-guard, switches to the 'Tie Fighter' hyprmon profile, and cleans up AFK resources

## Installation

### Quick Install

Run the installation script to install `afk` to your local bin directory and create a desktop entry:

```bash
./install.sh
```

This will:
- Copy `afk.sh` to `~/.local/bin/afk` and make it executable
- Install a desktop entry to `~/.local/share/applications/afk.desktop` so it appears in rofi and other application launchers
- Update the desktop database (if `update-desktop-database` is available)

### Manual Install

1. Make the script executable:
   ```bash
   chmod +x afk.sh
   ```

2. Optionally, create a symlink or copy to your PATH:
   ```bash
   ln -s $(pwd)/afk.sh ~/.local/bin/afk
   # or
   cp afk.sh ~/.local/bin/afk
   chmod +x ~/.local/bin/afk
   ```

3. Optionally, install the desktop entry manually:
   ```bash
   mkdir -p ~/.local/share/applications
   cp afk.desktop ~/.local/share/applications/
   update-desktop-database ~/.local/share/applications  # if available
   ```

## Usage

You can run the AFK application in several ways:

**Command line:**
```bash
./afk.sh
# or if installed:
afk
```

**Application launcher:**
- Search for "AFK Toggle" in rofi, dmenu, or your application menu
- The desktop entry will appear after installation

The script will automatically detect the current mode and toggle to the opposite mode.

## Dependencies

The following tools must be installed and available in your PATH:

- **hyprmon** - For profile switching
- **tmux** - For session management
- **sleep-guard** - Must be in PATH (or set `SLEEP_GUARD_CMD` environment variable)
- **pkill**/**pgrep** - For process management (usually in `procps` package)
- **bash** - Shell interpreter (version 4.0+)

## How It Works

### Mode Detection

The script uses multiple indicators to robustly detect the current mode:

1. **Lock file**: Checks for `/tmp/afk-mode.lock`
2. **Tmux session**: Checks if tmux session 'afk' exists
3. **Process check**: Checks if sleep-guard is running

If two or more indicators suggest AFK mode, the script considers the system to be in AFK mode. This handles edge cases where one indicator might be inconsistent.

### AFK Mode Activation

When switching **TO** AFK mode:

1. Switches hyprmon profile to 'afk'
2. Creates tmux session 'afk' if it doesn't exist
3. Starts sleep-guard in the tmux session (if not already running)
4. Launches a terminal window showing the tmux session
5. Creates a lock file at `/tmp/afk-mode.lock`

### Present Mode Activation

When switching **TO** present mode:

1. Kills the sleep-guard process
2. Switches hyprmon profile to 'Tie Fighter'
3. Removes the lock file

### Terminal Detection

The script automatically detects your terminal emulator by checking:

1. `$TERMINAL` environment variable
2. `$TERM_PROGRAM` environment variable
3. Common terminal emulators: alacritty, kitty, foot, wezterm, gnome-terminal, konsole, xterm

If no GUI terminal is found, it attempts to attach directly to the tmux session.

## Configuration

You can customize the behavior by modifying variables at the top of `afk.sh`:

- `TMUX_SESSION`: Name of the tmux session (default: "afk")
- `AFK_PROFILE`: hyprmon profile name for AFK mode (default: "afk")
- `PRESENT_PROFILE`: hyprmon profile name for present mode (default: "Tie Fighter")
- `SLEEP_GUARD_CMD`: Command to run sleep-guard (default: "sleep-guard")
- `LOCK_FILE`: Path to lock file (default: "/tmp/afk-mode.lock")

## Troubleshooting

### hyprmon command not found

Install hyprmon or ensure it's in your PATH. Verify with:
```bash
command -v hyprmon
```

### tmux session already exists

The script handles this automatically. If you encounter issues, you can manually kill the session:
```bash
tmux kill-session -t afk
```

### sleep-guard not found

Ensure sleep-guard is installed and in your PATH, or set the `SLEEP_GUARD_CMD` environment variable:
```bash
export SLEEP_GUARD_CMD="/path/to/sleep-guard"
```

### Terminal not launching

The script will attempt to detect your terminal automatically. If it fails:
1. Set the `TERMINAL` environment variable: `export TERMINAL=your-terminal`
2. Or manually attach to the tmux session: `tmux attach -t afk`

### Desktop entry shows "command not found"

If the desktop entry was installed before a recent update, it may be using the old format. Reinstall to fix:
```bash
./install.sh
```

This will update the desktop entry to use the full path to the installed script.

### Application does nothing when launched from desktop entry

If the application appears to do nothing when launched from rofi or other launchers:

1. **Check the log file** for errors:
   ```bash
   cat ~/.local/share/afk/afk.log
   ```

2. **Test from command line** to see if it works:
   ```bash
   afk
   ```

3. **Check environment variables** - Desktop entries may not have DISPLAY/WAYLAND_DISPLAY set. The script tries to auto-detect these, but you can verify:
   ```bash
   echo $DISPLAY
   echo $WAYLAND_DISPLAY
   ```

4. **Reinstall** to ensure the desktop entry is up to date:
   ```bash
   ./install.sh
   ```

5. **Check if the script is executable**:
   ```bash
   ls -l ~/.local/bin/afk
   ```

### Multiple instances running

The script doesn't prevent multiple instances from running simultaneously. If you encounter issues:
1. Check for running instances: `ps aux | grep afk.sh`
2. Kill any stuck processes
3. Clean up state: `rm -f /tmp/afk-mode.lock`

### Lock file exists but state is inconsistent

If the lock file exists but the actual state doesn't match:
1. Manually check tmux sessions: `tmux list-sessions`
2. Check if sleep-guard is running: `pgrep -f sleep-guard`
3. Remove lock file if needed: `rm -f /tmp/afk-mode.lock`
4. Run the script again to resync state

## Edge Cases Handled

- tmux session 'afk' already exists when switching to AFK mode
- sleep-guard already running when switching to AFK mode
- sleep-guard not running when switching to present mode
- hyprmon command fails or doesn't exist (with error reporting)
- Terminal emulator not detected (falls back to direct tmux attach)
- Running from systemd or without display (uses systemd-run)

## License

See the LICENSE file in the parent directory or check with the project maintainer.
