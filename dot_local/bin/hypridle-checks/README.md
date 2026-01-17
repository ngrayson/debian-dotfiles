# Hypridle Idle Inhibition Scripts

This directory contains scripts that prevent hypridle from locking the screen or turning off the display when certain conditions are met (media playback, fullscreen windows, or games running).

## Overview

The scripts work together to detect conditions that should prevent idle actions:

- **Media Detection**: Checks for active media playback via MPRIS (Spotify, YouTube in browsers, etc.)
- **Fullscreen Detection**: Checks if any window is in fullscreen mode
- **Game Detection**: Checks if games are running (Steam, native games, Wine/Proton)

When any of these conditions are active, idle actions (screen lock, screen off) are prevented.

## Scripts

### `check-media-playing.sh`
Checks if any media is currently playing via MPRIS (Media Player Remote Interfacing Specification).

**Dependencies**: `dbus-send`

**Exit codes**:
- `0` - Media is playing
- `1` - No media playing
- `2` - Error (D-Bus unavailable, etc.)

**Usage**:
```bash
check-media-playing.sh [--verbose]
```

**Supported players**: Spotify, Firefox (YouTube), Chromium (YouTube), VLC, mpv, and any MPRIS-compatible player.

### `check-fullscreen.sh`
Checks if any window is currently in fullscreen mode using `hyprctl`.

**Dependencies**: `hyprctl`, `jq` (optional, for better JSON parsing)

**Exit codes**:
- `0` - Fullscreen window detected
- `1` - No fullscreen window
- `2` - Error (hyprctl unavailable, etc.)

**Usage**:
```bash
check-fullscreen.sh [--verbose]
```

### `check-games.sh`
Checks if any games are currently running by matching window classes.

**Dependencies**: `hyprctl`, `jq` (optional)

**Exit codes**:
- `0` - Game detected
- `1` - No game detected
- `2` - Error (hyprctl unavailable, etc.)

**Usage**:
```bash
check-games.sh [--verbose]
```

**Detected patterns**:
- Steam games: `steam_app_*`, `steam_proton_*`
- Game launchers: `lutris`, `heroic`
- Common game patterns: `game`, `unity`, `unreal`, `godot`, `rpg`
- Wine/Proton: `wine`, `proton`

**Note**: The Steam client itself and Lutris launcher are filtered out (only actual games are detected).

### `check-idle-inhibited.sh`
Master script that runs all detection scripts and returns 0 if ANY condition prevents idle.

**Dependencies**: All above scripts

**Exit codes**:
- `0` - Idle should be inhibited (media/fullscreen/games active)
- `1` - Idle can proceed (no inhibiting conditions)
- `2` - Error in script execution

**Usage**:
```bash
check-idle-inhibited.sh [--verbose]
```

This is the script that hypridle calls to check if idle actions should be prevented.

## Diagnostic Tool

### `hypridle-status.sh`
Provides human-readable status of idle inhibition checks.

**Usage**:
```bash
hypridle-status.sh [--verbose] [--json]
```

**Options**:
- `--verbose` or `-v`: Show detailed information for each check
- `--json` or `-j`: Output in JSON format for scripting

**Example output**:
```
Idle Status: INHIBITED
Reason: Media playback, Fullscreen window

Details:
  Media:     PLAYING
    Media playing: Spotify - Artist - Song Name
  Fullscreen: YES
    Fullscreen window: firefox - YouTube
  Games:      NO
```

## Configuration

### Hypridle Integration

The scripts are integrated into `~/.config/hypr/hypridle.conf`:

```conf
# Lock screen listener - checks for media/fullscreen/games before locking
listener {
    timeout = 300                                             # 5min
    on-timeout = ~/.local/bin/hypridle-checks/check-idle-inhibited.sh || loginctl lock-session
}

# Screen off listener - checks for media/fullscreen/games before turning off screen
listener {
    timeout = 600                                             # 10min
    on-timeout = ~/.local/bin/hypridle-checks/check-idle-inhibited.sh || hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on && brightnessctl -r
}
```

**How it works**: The `||` operator means "if the left command fails (returns non-zero), execute the right command". So:
- If `check-idle-inhibited.sh` returns 0 (idle inhibited), the chain stops and the action doesn't execute
- If `check-idle-inhibited.sh` returns non-zero (idle not inhibited), the action (lock/screen off) executes

### Chezmoi Integration

All scripts are managed via chezmoi dotfiles:

- Scripts: `~/.local/share/chezmoi/dot_local/bin/hypridle-checks/`
- Config: `~/.local/share/chezmoi/dot_config/hypr/hypridle.conf`

After making changes, apply with:
```bash
chezmoi apply
```

## Testing

### Manual Testing

1. **Test media detection**:
   ```bash
   # Start Spotify or play YouTube video
   ~/.local/bin/hypridle-checks/check-media-playing.sh --verbose
   ```

2. **Test fullscreen detection**:
   ```bash
   # Enter fullscreen in any application
   ~/.local/bin/hypridle-checks/check-fullscreen.sh --verbose
   ```

3. **Test game detection**:
   ```bash
   # Launch a game
   ~/.local/bin/hypridle-checks/check-games.sh --verbose
   ```

4. **Test overall status**:
   ```bash
   ~/.local/bin/hypridle-status.sh --verbose
   ```

5. **Test idle inhibition**:
   ```bash
   # Should return 0 if any condition is active
   ~/.local/bin/hypridle-checks/check-idle-inhibited.sh --verbose
   ```

### Integration Testing

1. **Test lock prevention**:
   - Start media playback or enter fullscreen
   - Wait for lock timeout (5 minutes)
   - Verify screen does NOT lock

2. **Test screen off prevention**:
   - Start media playback or enter fullscreen
   - Wait for screen off timeout (10 minutes)
   - Verify screen does NOT turn off

3. **Test normal idle behavior**:
   - Ensure no media/fullscreen/games
   - Wait for timeout
   - Verify screen locks/turns off normally

## Troubleshooting

### Scripts not found

If hypridle can't find the scripts:
1. Verify scripts are installed: `ls ~/.local/bin/hypridle-checks/`
2. Verify scripts are executable: `ls -l ~/.local/bin/hypridle-checks/`
3. Check hypridle config paths are correct
4. Reload hypridle: `hypridle` (restart the service)

### Media not detected

1. Verify MPRIS is available: `dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames | grep mpris`
2. Check if player supports MPRIS (most modern players do)
3. Run with verbose: `check-media-playing.sh --verbose`

### Fullscreen not detected

1. Verify hyprctl works: `hyprctl clients`
2. Check if window is actually fullscreen (not just maximized)
3. Run with verbose: `check-fullscreen.sh --verbose`

### Games not detected

1. Check window class: `hyprctl clients -j | jq '.[] | .class'`
2. Add game pattern to `check-games.sh` if needed
3. Run with verbose: `check-games.sh --verbose`

### Performance Issues

Scripts should execute in < 100ms. If slow:
1. Check if `jq` is installed (faster JSON parsing)
2. Monitor script execution time: `time check-idle-inhibited.sh`
3. Check system load

## Adding New Detection Conditions

To add a new detection condition:

1. Create a new check script (e.g., `check-custom.sh`)
2. Make it executable and follow the exit code convention:
   - `0` = condition active (inhibit idle)
   - `1` = condition not active (allow idle)
   - `2` = error
3. Add it to `check-idle-inhibited.sh`
4. Update `hypridle-status.sh` to report the new condition
5. Test thoroughly

## Dependencies

- `bash` - Shell interpreter
- `hyprctl` - Hyprland control utility (for fullscreen/game detection)
- `dbus-send` - D-Bus command-line tool (for media detection)
- `jq` - JSON parser (optional, but recommended for better performance)
- `grep`, `sed`, `cut` - Standard Unix utilities

## Related Files

- `~/.config/hypr/hypridle.conf` - Hypridle configuration
- `~/.local/bin/hypridle-status.sh` - Diagnostic tool
- Test plan: `plans/hypridle-media-fullscreen-test-plan.md`

## Notes

- Scripts are designed to be fast (< 100ms) to avoid impacting system performance
- Scripts fail safe: if a check script fails, idle is allowed (better than blocking)
- Multiple conditions are additive: if ANY condition is active, idle is inhibited
- The system works alongside existing media-idle-inhibitor.sh daemon (if used)
