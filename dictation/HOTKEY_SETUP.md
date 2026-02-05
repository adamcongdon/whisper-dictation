# Dictation Hotkey Setup

Trigger dictation with a keyboard shortcut or Stream Deck button.

## Prerequisites

1. Whisper server running: `./scripts/start-server.sh`
2. Grant accessibility permissions (see below)

## Quick Test

```bash
# Test the script manually first
~/code/voiceProgram/scripts/hotkey-dictate.sh --clipboard
```

Speak for a few seconds, then wait for silence detection to stop recording.

---

## Option 1: Stream Deck (Recommended)

### Setup

1. Open Stream Deck app
2. Drag "System > Open" action to a button
3. Set App/File to: `/Users/adam.congdon/code/voiceProgram/scripts/hotkey-dictate.sh`
4. Or use "Multi Action" with:
   - Open: `/bin/bash`
   - Args: `-c "/Users/adam.congdon/code/voiceProgram/scripts/hotkey-dictate.sh --type"`

### Alternative: Stream Deck CLI Plugin

If you have the CLI plugin:
1. Add "Run Command" action
2. Command: `/Users/adam.congdon/code/voiceProgram/scripts/hotkey-dictate.sh --type`

---

## Option 2: macOS Keyboard Shortcut (Automator)

### Step 1: Create Automator Quick Action

1. Open **Automator** (Applications > Automator)
2. Choose **Quick Action**
3. Set "Workflow receives" to **no input** in **any application**
4. Add action: **Run Shell Script**
5. Paste:
   ```bash
   /Users/adam.congdon/code/voiceProgram/scripts/hotkey-dictate.sh --type
   ```
6. Save as "Dictate"

### Step 2: Assign Keyboard Shortcut

1. Open **System Settings > Keyboard > Keyboard Shortcuts**
2. Select **Services** (or **App Shortcuts** on older macOS)
3. Find "Dictate" under General
4. Assign shortcut (e.g., `Ctrl+Shift+D` or `Hyper+D`)

---

## Option 3: Raycast

1. Install Raycast (raycast.com)
2. Create Script Command:
   ```bash
   #!/bin/bash
   # @raycast.title Dictate
   # @raycast.mode silent

   /Users/adam.congdon/code/voiceProgram/scripts/hotkey-dictate.sh --type
   ```
3. Assign hotkey in Raycast preferences

---

## Option 4: Hammerspoon

Install Hammerspoon, add to `~/.hammerspoon/init.lua`:

```lua
-- Dictation hotkey: Hyper + D
hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "d", function()
    hs.execute("/Users/adam.congdon/code/voiceProgram/scripts/hotkey-dictate.sh --type", true)
end)
```

Reload config: `hs.reload()`

---

## Accessibility Permissions

The script uses AppleScript to type text. Grant permissions:

1. **System Settings > Privacy & Security > Accessibility**
2. Add and enable:
   - Terminal (or iTerm2)
   - Stream Deck (if using)
   - Automator (if using Quick Action)

---

## Script Options

| Flag | Behavior |
|------|----------|
| `--type` | Types text into active window (default) |
| `--clipboard` | Copies to clipboard only |
| `--both` | Types AND copies to clipboard |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WHISPER_HOST` | localhost | Whisper server host |
| `WHISPER_PORT` | 8889 | Whisper server port |
| `RECORD_DURATION` | 15 | Max recording seconds |
| `SILENCE_DURATION` | 1.5 | Seconds of silence to stop |

## Troubleshooting

### "Whisper server not running"
```bash
./scripts/start-server.sh
```

### Text not typing
- Check Accessibility permissions
- Try `--clipboard` mode instead
- Check Terminal/app is focused

### Recording too short/long
```bash
# Longer max duration
RECORD_DURATION=30 ./scripts/hotkey-dictate.sh

# Faster silence cutoff
SILENCE_DURATION=1.0 ./scripts/hotkey-dictate.sh
```

### No notification sound
- Check System Settings > Notifications > Script Editor
- Enable notifications for Terminal
