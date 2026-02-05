# iPhone Dictation Setup

Connect your iPhone to your Mac's whisper.cpp server for transcription.

## Prerequisites

1. Mac running whisper-server (port 8889)
2. iPhone on same network as Mac
3. Know your Mac's local IP address

## Find Your Mac's IP

On your Mac, run:
```bash
ipconfig getifaddr en0
```

Example: `192.168.1.100`

## iOS Shortcut Setup

### Method 1: Simple Voice Recording Shortcut

1. Open **Shortcuts** app on iPhone
2. Create new Shortcut
3. Add these actions:

```
1. Record Audio
   - Quality: Normal
   - Start Recording: On Tap
   - Finish Recording: On Tap

2. Get Contents of URL
   - URL: http://YOUR_MAC_IP:8889/inference
   - Method: POST
   - Request Body: Form
   - Add Field:
     - Key: file
     - Type: File
     - Value: Shortcut Input (the recording)
   - Add Field:
     - Key: response_format
     - Value: json

3. Get Dictionary Value
   - Key: text
   - Dictionary: Contents of URL

4. Copy to Clipboard
   - Input: Dictionary Value

5. Show Result
   - Input: Dictionary Value
```

4. Name it "Dictate" and add to Home Screen

### Method 2: Quick Voice Note

Simpler version that just copies the transcription:

1. **Record Audio** (On Tap / On Tap)
2. **Get Contents of URL** (POST to `http://YOUR_MAC_IP:8889/inference`, form data with `file` and `response_format=json`)
3. **Get Dictionary Value** (key: `text`)
4. **Copy to Clipboard**
5. **Show Notification** ("Transcription copied!")

## Usage

1. Make sure whisper-server is running on Mac:
   ```bash
   ./scripts/start-server.sh
   ```

2. Run the Shortcut on iPhone
3. Speak your message
4. Tap to stop recording
5. Wait for transcription (2-5 seconds)
6. Result is copied to clipboard

## Troubleshooting

### "Could not connect to server"

1. Check Mac IP address is correct
2. Ensure both devices on same WiFi network
3. Check server is running: `curl http://YOUR_MAC_IP:8889/`
4. Check firewall allows port 8889

### "Request timed out"

- Long recordings take longer to process
- Try shorter recordings first
- Consider using the `large` model for better accuracy

### Firewall Configuration

If needed, allow incoming connections:
```bash
# Add firewall rule (macOS)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /opt/homebrew/bin/whisper-server
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /opt/homebrew/bin/whisper-server
```

## Advanced: Siri Integration

Add a Siri trigger to your Shortcut:
1. In Shortcut settings, add "Siri Phrase"
2. Set phrase like "Transcribe this"
3. Now say "Hey Siri, transcribe this" to start dictation

## API Reference

The whisper-server `/inference` endpoint accepts:

| Parameter | Type | Description |
|-----------|------|-------------|
| `file` | File | Audio file (wav, mp3, m4a, etc.) |
| `response_format` | String | `json`, `text`, `srt`, or `vtt` |
| `temperature` | Float | Sampling temperature (0.0 recommended) |

### JSON Response Format

```json
{
  "text": "The transcribed text appears here."
}
```

### Example curl

```bash
curl http://192.168.1.100:8889/inference \
  -F "file=@recording.m4a" \
  -F "response_format=json"
```
