#!/bin/bash
#
# Whisper Dictation Installer
# Hold Right Command to dictate anywhere on macOS
#
# Install: curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/install.sh | bash
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

INSTALL_DIR="$HOME/.local/share/whisper-dictation"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
MODEL_PATH="$HOME/.whisper/ggml-base.en.bin"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}       🎤 Whisper Dictation Installer${NC}"
echo -e "${BLUE}       Hold Right ⌘ to dictate anywhere${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This installer only works on macOS${NC}"
    exit 1
fi

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
    echo -e "${RED}Error: Unsupported architecture: $ARCH${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} macOS $ARCH detected"

# Install Homebrew if needed
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add to path for this session
    if [[ "$ARCH" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi
echo -e "${GREEN}✓${NC} Homebrew ready"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
brew install sox whisper-cpp 2>/dev/null || brew upgrade sox whisper-cpp 2>/dev/null || true
echo -e "${GREEN}✓${NC} sox and whisper-cpp installed"

# Install Hammerspoon
if ! brew list --cask hammerspoon &>/dev/null; then
    echo -e "${YELLOW}Installing Hammerspoon...${NC}"
    brew install --cask hammerspoon
fi
echo -e "${GREEN}✓${NC} Hammerspoon installed"

# Download whisper model
mkdir -p "$HOME/.whisper"
if [[ ! -f "$MODEL_PATH" ]]; then
    echo -e "${YELLOW}Downloading Whisper model (141MB)...${NC}"
    curl -L -o "$MODEL_PATH" "$MODEL_URL"
fi
echo -e "${GREEN}✓${NC} Whisper model ready"

# Create install directory
mkdir -p "$INSTALL_DIR"

# Create record-start script
cat > "$INSTALL_DIR/record-start.sh" << 'SCRIPT'
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
TEMP_FILE="/tmp/dictation-ptt.wav"
PID_FILE="/tmp/dictation-ptt.pid"
[ -f "$PID_FILE" ] && kill $(cat "$PID_FILE") 2>/dev/null
rm -f "$PID_FILE" "$TEMP_FILE"
rec -q "$TEMP_FILE" rate 16k channels 1 &
echo $! > "$PID_FILE"
SCRIPT
chmod +x "$INSTALL_DIR/record-start.sh"

# Create record-stop script
cat > "$INSTALL_DIR/record-stop.sh" << 'SCRIPT'
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
TEMP_FILE="/tmp/dictation-ptt.wav"
PID_FILE="/tmp/dictation-ptt.pid"
MODEL="${WHISPER_MODEL:-$HOME/.whisper/ggml-base.en.bin}"
WHISPER_PORT="${WHISPER_PORT:-8889}"
MODE="${1:---type}"

# Stop recording
[ -f "$PID_FILE" ] && kill $(cat "$PID_FILE") 2>/dev/null && sleep 0.2
rm -f "$PID_FILE"

[ ! -s "$TEMP_FILE" ] && exit 1

# Check if server is running, otherwise use CLI
if curl -s "http://localhost:$WHISPER_PORT/" >/dev/null 2>&1; then
    RESPONSE=$(curl -s "http://localhost:$WHISPER_PORT/inference" \
        -F "file=@${TEMP_FILE}" \
        -F "response_format=json" \
        -F "temperature=0.0")
    TEXT=$(echo "$RESPONSE" | python3 -c "import sys,json,re; t=json.load(sys.stdin).get('text','').strip(); t=re.sub(r'\[BLANK_AUDIO\]','',t); t=re.sub(r'\(.*?\)','',t); t=re.sub(r'\s+',' ',t).strip(); print(t)" 2>/dev/null)
else
    # Use CLI directly (slower but works without server)
    TEXT=$(whisper-cli -m "$MODEL" -f "$TEMP_FILE" --no-timestamps 2>/dev/null | python3 -c "import sys,re; t=sys.stdin.read().strip(); t=re.sub(r'\[BLANK_AUDIO\]','',t); t=re.sub(r'\(.*?\)','',t); t=re.sub(r'\s+',' ',t).strip(); print(t)" 2>/dev/null)
fi

rm -f "$TEMP_FILE"
[ -z "$TEXT" ] && exit 1

case "$MODE" in
    --clipboard) echo -n "$TEXT" | pbcopy ;;
    --type|*) osascript -e "tell application \"System Events\" to keystroke \"$TEXT\"" ;;
esac
SCRIPT
chmod +x "$INSTALL_DIR/record-stop.sh"

# Create server start script
cat > "$INSTALL_DIR/start-server.sh" << 'SCRIPT'
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
MODEL="${WHISPER_MODEL:-$HOME/.whisper/ggml-base.en.bin}"
PORT="${WHISPER_PORT:-8889}"
pgrep -f "whisper-server.*$PORT" && exit 0
nohup whisper-server -m "$MODEL" --host 0.0.0.0 --port "$PORT" > /tmp/whisper-server.log 2>&1 &
sleep 2
pgrep -f "whisper-server.*$PORT" && echo "Server started on port $PORT" || echo "Failed to start"
SCRIPT
chmod +x "$INSTALL_DIR/start-server.sh"

echo -e "${GREEN}✓${NC} Scripts installed to $INSTALL_DIR"

# Setup Hammerspoon config (ROBUST with debouncing)
mkdir -p "$HOME/.hammerspoon"
cat > "$HOME/.hammerspoon/init.lua" << HSCONFIG
-- Whisper Dictation: Hold Right Command to dictate
-- ROBUST: Debouncing, state verification, auto-cleanup

local isRecording = false
local rightCmdDown = false
local rightOptDown = false
local lastActionTime = 0
local DEBOUNCE_MS = 500
local installDir = "$INSTALL_DIR"

local function isActuallyRecording()
    local _, status = hs.execute("pgrep -x rec")
    return status
end

local function shouldDebounce()
    local now = hs.timer.secondsSinceEpoch() * 1000
    if (now - lastActionTime) < DEBOUNCE_MS then return true end
    lastActionTime = now
    return false
end

local function forceCleanup()
    os.execute("pkill -9 -x rec 2>/dev/null; rm -f /tmp/dictation-ptt.* 2>/dev/null")
    isRecording = false
    rightCmdDown = false
    rightOptDown = false
end

local function reloadConfig(files)
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then forceCleanup(); hs.reload() end
    end
end
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

local function startRecording(mode)
    if shouldDebounce() then return end
    if isRecording then return end
    if isActuallyRecording() then forceCleanup(); return end
    isRecording = true
    hs.alert.show("🎤", 0.3)
    os.execute(installDir .. "/record-start.sh &")
end

local function stopRecording(mode)
    if shouldDebounce() then return end
    if not isRecording then
        if isActuallyRecording() then forceCleanup() end
        return
    end
    isRecording = false
    hs.alert.show("⏳", 0.3)
    local arg = mode == "clipboard" and "--clipboard" or "--type"
    os.execute(installDir .. "/record-stop.sh " .. arg .. " &")
end

local cmdWatcher = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
    local keyCode = event:getKeyCode()
    local flags = event:getFlags()
    if keyCode == 54 then
        if flags.cmd and not rightCmdDown then
            rightCmdDown = true
            startRecording("type")
        elseif not flags.cmd and rightCmdDown then
            rightCmdDown = false
            stopRecording("type")
        end
    end
    return false
end)
if not cmdWatcher:start() then
    hs.alert.show("⚠️ Failed - check Accessibility permissions", 5)
end

local optWatcher = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
    local keyCode = event:getKeyCode()
    local flags = event:getFlags()
    if keyCode == 61 then
        if flags.alt and not rightOptDown then
            rightOptDown = true
            startRecording("clipboard")
        elseif not flags.alt and rightOptDown then
            rightOptDown = false
            stopRecording("clipboard")
        end
    end
    return false
end)
optWatcher:start()

hs.hotkey.bind({"cmd", "ctrl"}, "r", function() forceCleanup(); hs.reload() end)
hs.hotkey.bind({"cmd", "ctrl"}, "h", function()
    local s = "State: " .. (isRecording and "Recording" or "Idle") .. "\\n"
    s = s .. "Process: " .. (isActuallyRecording() and "⚠️ Running" or "✓ None")
    hs.alert.show(s, 3)
end)
hs.hotkey.bind({"cmd", "ctrl"}, "escape", function()
    forceCleanup()
    hs.alert.show("🔄 Reset", 1)
end)

forceCleanup()
hs.alert.show("🎤 Hold Right ⌘ to dictate", 2)
HSCONFIG

echo -e "${GREEN}✓${NC} Hammerspoon configured"

# Optionally start the server for faster transcription
echo ""
echo -e "${YELLOW}Starting whisper server for faster transcription...${NC}"
"$INSTALL_DIR/start-server.sh"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}       ✓ Installation Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}⚠️  REQUIRED: Grant permissions to Hammerspoon${NC}"
echo ""
echo "   1. Accessibility (for typing text):"
echo "      System Settings → Privacy & Security → Accessibility"
echo "      → Add Hammerspoon and enable"
echo ""
echo "   2. Microphone (for recording):"
echo "      System Settings → Privacy & Security → Microphone"
echo "      → Enable for Hammerspoon"
echo ""

# Open System Settings to Accessibility
echo -e "${YELLOW}Opening System Settings...${NC}"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

echo ""
echo "After granting permissions, Hammerspoon will launch automatically."
echo ""
read -p "Press Enter when you've granted permissions..."

# Launch Hammerspoon
echo -e "${YELLOW}Launching Hammerspoon...${NC}"
open -a Hammerspoon

echo ""
echo -e "${GREEN}🎉 Done! Hold Right ⌘ to dictate anywhere.${NC}"
echo ""
echo "Tips:"
echo "  • Hold Right ⌘ → dictate → release → text types"
echo "  • Hold Right ⌥ → dictate → release → copies to clipboard"
echo "  • Cmd+Ctrl+R → reload Hammerspoon config"
echo ""
