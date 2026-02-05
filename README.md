# Whisper Dictation

**Hold Right ⌘ to dictate anywhere on macOS** — like SuperWhisper, but free and local.

Uses whisper.cpp for speech recognition. No cloud, no subscription, runs entirely on your Mac.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/whisper-dictation/main/install.sh | bash
```

Or clone and run:
```bash
git clone https://github.com/YOUR_USERNAME/whisper-dictation.git
cd whisper-dictation
./install.sh
```

## Usage

| Key | Action |
|-----|--------|
| **Hold Right ⌘** | Dictate → release → text types at cursor |
| **Hold Right ⌥** | Dictate → release → copies to clipboard |
| **Cmd+Ctrl+R** | Reload Hammerspoon config |

## Requirements

- macOS (Apple Silicon or Intel)
- Internet connection (for initial install)
- ~300MB disk space (model + dependencies)

## What Gets Installed

| Component | Purpose |
|-----------|---------|
| [Homebrew](https://brew.sh) | Package manager (if not present) |
| [sox](https://sox.sourceforge.net) | Audio recording |
| [whisper-cpp](https://github.com/ggerganov/whisper.cpp) | Speech recognition |
| [Hammerspoon](https://www.hammerspoon.org) | Hotkey detection |
| ggml-base.en.bin | Whisper model (141MB) |

## Permissions Required

After install, grant these permissions to **Hammerspoon**:

1. **System Settings → Privacy & Security → Accessibility** → Enable Hammerspoon
2. **System Settings → Privacy & Security → Microphone** → Enable Hammerspoon

## Configuration

### Change Whisper Model

For better accuracy (slower):
```bash
# Download medium model (1.5GB)
curl -L -o ~/.whisper/ggml-medium.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin

# Set in your shell profile
export WHISPER_MODEL=~/.whisper/ggml-medium.en.bin
```

### Faster Mode (with server)

The installer starts a whisper server for faster transcription. To manage it:

```bash
# Start server
~/.local/share/whisper-dictation/start-server.sh

# Check if running
pgrep -f whisper-server

# Stop server
pkill -f whisper-server
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/whisper-dictation/main/uninstall.sh | bash
```

Or:
```bash
./uninstall.sh
```

## Troubleshooting

### Text not typing
- Check Accessibility permissions for Hammerspoon
- Reload config: Cmd+Ctrl+R

### No transcription
- Check Microphone permissions for Hammerspoon
- Check whisper server: `curl http://localhost:8889/`
- Check logs: `cat /tmp/whisper-server.log`

### Hammerspoon not responding
- Quit and reopen Hammerspoon
- Check Console.app for errors

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Hold Right ⌘                                                   │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────────┐   │
│  │ Hammerspoon │────▶│ record-start│────▶│  sox (rec)      │   │
│  │ (eventtap)  │     │    .sh      │     │  records audio  │   │
│  └─────────────┘     └─────────────┘     └─────────────────┘   │
│                                                                 │
│  Release Right ⌘                                                │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────────┐   │
│  │ Hammerspoon │────▶│ record-stop │────▶│  whisper-server │   │
│  │             │     │    .sh      │     │  or whisper-cli │   │
│  └─────────────┘     └─────────────┘     └────────┬────────┘   │
│                                                    │            │
│                                                    ▼            │
│                                          ┌─────────────────┐   │
│                                          │ System Events   │   │
│                                          │ (keystroke)     │   │
│                                          └─────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## License

MIT

## Credits

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov
- [Hammerspoon](https://www.hammerspoon.org)
- Inspired by [SuperWhisper](https://superwhisper.com)
