#!/bin/bash
#
# Whisper Dictation Uninstaller
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/share/whisper-dictation"

echo ""
echo -e "${YELLOW}Uninstalling Whisper Dictation...${NC}"
echo ""

# Stop services
pkill -f whisper-server 2>/dev/null || true
pkill -f Hammerspoon 2>/dev/null || true

# Remove scripts
if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✓${NC} Removed $INSTALL_DIR"
fi

# Remove Hammerspoon config (backup first)
if [[ -f "$HOME/.hammerspoon/init.lua" ]]; then
    mv "$HOME/.hammerspoon/init.lua" "$HOME/.hammerspoon/init.lua.backup"
    echo -e "${GREEN}✓${NC} Backed up Hammerspoon config to init.lua.backup"
fi

# Optionally remove model
read -p "Remove whisper model (~141MB)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$HOME/.whisper/ggml-base.en.bin"
    echo -e "${GREEN}✓${NC} Removed whisper model"
fi

echo ""
echo -e "${GREEN}✓ Uninstall complete${NC}"
echo ""
echo "Note: Homebrew packages (sox, whisper-cpp, hammerspoon) were not removed."
echo "To remove them: brew uninstall sox whisper-cpp && brew uninstall --cask hammerspoon"
echo ""
