# Tmux Startup Script

Automatically creates a tmux session with configured panes running TUI programs (like fastfetch, btop, htop) on system startup.

## Features

- **Configurable pane layouts**: Define pane sizes and positions via configuration file
- **Automatic program execution**: Run commands in each pane automatically
- **Session management**: Handles existing sessions gracefully (skip, attach, or recreate)
- **Systemd integration**: Starts automatically after graphical session is ready
- **Flexible sizing**: Supports percentage-based pane sizing
- **Error handling**: Robust error checking and logging

## Files

- `tmux-startup.sh` - Main script that creates and configures the tmux session
- `config.sh` - Configuration file for customizing pane layouts and programs
- `tmux-startup.service` - Systemd user service file for automatic startup
- `README.md` - This documentation

## Installation

### 1. Make scripts executable

```bash
chmod +x tmux-startup.sh
chmod +x config.sh
```

### 2. Configure your layout

Edit `config.sh` to customize:
- Session name
- Pane layouts and sizes
- Commands to run in each pane
- Terminal emulator (if needed)
- Behavior when session already exists

### 3. Test the script manually

```bash
./tmux-startup.sh
```

Then attach to the session:
```bash
tmux attach -t startup
```

### 4. Install systemd service

Copy the service file to your user systemd directory:

```bash
mkdir -p ~/.config/systemd/user
cp tmux-startup.service ~/.config/systemd/user/
```

**Note:** The service will automatically launch a terminal window on startup. The terminal emulator is auto-detected, or you can specify it in `config.sh` using `TERMINAL_CMD`.

### 5. Edit service file path (if needed)

If you installed the scripts to a different location, edit `~/.config/systemd/user/tmux-startup.service` and update the `ExecStart` path.

### 6. Enable and start the service

```bash
systemctl --user daemon-reload
systemctl --user enable tmux-startup.service
systemctl --user start tmux-startup.service
```

### 7. Check service status

```bash
systemctl --user status tmux-startup.service
```

View logs:
```bash
journalctl --user -u tmux-startup.service -f
```

## Configuration

### Basic Configuration (`config.sh`)

```bash
# Session name
SESSION_NAME="startup"

# Terminal command (empty = use default)
TERMINAL_CMD=""

# Attach to session after creation
ATTACH_SESSION=false

# Command to run in the initial pane (pane 0)
# Leave empty to not run any command in the first pane
INITIAL_PANE_CMD=""

# First active pane after session creation
# Specify which pane index should be active/selected (default: 0)
ACTIVE_PANE=0

# Behavior when session exists: "skip", "attach", or "recreate"
EXISTING_SESSION_ACTION="skip"

# Pane definitions
PANES=(
  "0 h 30 'fastfetch'"      # Split pane 0 horizontally, 30% width
  "1 v 40 'btop'"           # Split pane 1 vertically, 40% height
  "2 v 60 'htop'"           # Split pane 2 vertically, 60% height
)
```

### Pane Definition Format

Each pane definition follows this format:
```
"pane_index direction size 'command'"
```

- **pane_index**: The pane to split (0 = initial pane)
- **direction**: 
  - `h` = horizontal split (left-right, creates side-by-side panes)
  - `v` = vertical split (top-bottom, creates stacked panes)
- **size**: Percentage (0-100) for the new pane size
- **command**: Command to run in the new pane (use single quotes)

### Example Configurations

#### Simple 2-pane layout:
```bash
INITIAL_PANE_CMD="fastfetch"
PANES=(
  "0 h 50 'btop'"
)
```

#### With initial pane command:
```bash
# Run fastfetch in the first pane, then split and run other programs
INITIAL_PANE_CMD="fastfetch"
PANES=(
  "0 h 50 'btop'"
  "1 v 50 'htop'"
)
```

#### 4-pane grid layout:
```bash
PANES=(
  "0 h 50 'fastfetch'"      # Split initial pane horizontally
  "0 v 50 'btop'"           # Split left pane vertically
  "2 v 50 'htop'"           # Split right pane vertically
)
```

#### Custom terminal emulator:
```bash
# Specify your preferred terminal emulator
TERMINAL_CMD="alacritty"
# When using systemd service, the terminal will launch automatically
# ATTACH_SESSION is ignored when running via systemd service
ATTACH_SESSION=false
```

#### Terminal auto-detection:
The systemd service will automatically detect and use one of these terminals (in order):
- alacritty
- kitty
- foot
- wezterm
- gnome-terminal
- konsole
- xterm
- x-terminal-emulator

Or set `TERMINAL_CMD` in `config.sh` to use a specific terminal.

#### Select a specific pane as active:
```bash
PANES=(
  "0 h 50 'btop'"
  "1 v 50 'htop'"
)
# Select pane 1 (the right pane) as active instead of pane 0
ACTIVE_PANE=1
```

## Usage

### Manual Execution

Run the script directly:
```bash
./tmux-startup.sh
```

### Attach to Session

```bash
tmux attach -t startup
```

Or if you configured a terminal:
```bash
tmux attach -t startup
```

### List Sessions

```bash
tmux ls
```

### Kill Session

```bash
tmux kill-session -t startup
```

## Troubleshooting

### Session not created on startup

1. Check if the service is enabled:
   ```bash
   systemctl --user is-enabled tmux-startup.service
   ```

2. Check service logs:
   ```bash
   journalctl --user -u tmux-startup.service -n 50
   ```

3. Verify the script path in the service file is correct

4. Check if tmux is installed:
   ```bash
   which tmux
   ```

### Programs not running

1. Verify programs are installed:
   ```bash
   which fastfetch btop htop
   ```

2. Test commands manually in a tmux pane

3. Check script logs for errors

### Pane sizes incorrect

- Pane sizes are percentages (0-100)
- The percentage refers to the size of the *new* pane created by the split
- Tmux may adjust sizes slightly to fit the terminal

### Environment variables missing

The systemd service includes common environment variables. If you need additional ones:

1. Edit `tmux-startup.service`
2. Add `Environment="VAR_NAME=value"` lines
3. Reload and restart:
   ```bash
   systemctl --user daemon-reload
   systemctl --user restart tmux-startup.service
   ```

### Session already exists

Configure `EXISTING_SESSION_ACTION` in `config.sh`:
- `skip` - Do nothing (default)
- `attach` - Attach to existing session
- `recreate` - Kill and recreate the session

## Advanced Usage

### Multiple sessions

Create multiple config files and service files for different session types:

```bash
cp config.sh config-work.sh
cp tmux-startup.service tmux-work.service
# Edit config-work.sh and tmux-work.service
```

### Conditional execution

Modify the script to check conditions before creating sessions (e.g., only on specific days, times, or system states).

### Custom tmux configuration

The script uses default tmux behavior. You can:
1. Create a `~/.tmux.conf` file for global tmux settings
2. Use `tmux -f /path/to/config.conf` in the script to use a specific config

## Uninstallation

1. Stop and disable the service:
   ```bash
   systemctl --user stop tmux-startup.service
   systemctl --user disable tmux-startup.service
   ```

2. Remove the service file:
   ```bash
   rm ~/.config/systemd/user/tmux-startup.service
   ```

3. Remove the script directory (optional):
   ```bash
   rm -r /home/wiz/Agent/tmux-startup
   ```

## License

This script is provided as-is for personal use.
