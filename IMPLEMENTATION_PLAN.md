# Custom Dictation & Voice Server Implementation Plan

**Created:** 2026-02-04
**Author:** KAI (for Adam)

---

## Executive Summary

This plan addresses two goals:
1. **Custom Dictation System** - Replace Apple's subpar dictation, works on locked corporate computers
2. **Custom Voice Server** - Replace expensive ElevenLabs API with cost-effective alternatives

**Key Finding:** GitHub Copilot SDK has **no speech capabilities**. We pivot to direct OpenAI/Deepgram APIs.

---

## Part 1: Custom Dictation System

### Option A: Corporate Locked Computer (Browser-Based Deepgram)

**Why Deepgram:**
- No software installation required (browser-only)
- WebSocket API for real-time streaming
- 92-94% accuracy, <300ms latency
- $0.007/minute (~$200 free credits to start)
- Full TypeScript SDK

**Architecture:**
```
Browser Microphone → WebSocket → Deepgram Nova-3 → Real-time Transcription
```

**Implementation:**

1. **Create Deepgram account** (https://console.deepgram.com)
   - Get API key
   - $200 free credits

2. **Build browser app** (`dictation/browser/`)
   ```typescript
   // deepgram-client.ts
   import { createClient, LiveTranscriptionEvents } from '@deepgram/sdk';

   const deepgram = createClient(process.env.DEEPGRAM_API_KEY);
   const connection = deepgram.listen.live({
     model: 'nova-3',
     language: 'en',
     smart_format: true,
     punctuate: true,
   });

   connection.on(LiveTranscriptionEvents.Transcript, (data) => {
     const transcript = data.channel.alternatives[0].transcript;
     // Display or process transcript
   });
   ```

3. **Create simple HTML UI**
   ```html
   <!DOCTYPE html>
   <html>
   <head><title>Dictation</title></head>
   <body>
     <button id="start">Start Dictation</button>
     <div id="transcript"></div>
     <script type="module" src="./main.js"></script>
   </body>
   </html>
   ```

4. **Host on GitHub Pages** (zero cost, accessible from work computer)

### Option B: Personal Mac (Local Whisper)

**Why whisper.cpp:**
- 95-97% accuracy (best available)
- Fully offline
- Core ML backend: 3x speedup on Apple Silicon
- Zero ongoing cost

**Installation:**
```bash
# Install via Homebrew
brew install whisper-cpp

# Or build from source with Core ML
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp
make clean
WHISPER_COREML=1 make -j

# Download model
./models/download-ggml-model.sh large-v2
```

**CLI Wrapper:**
```typescript
// whisper-cli.ts
import { execSync } from 'child_process';

export function transcribe(audioFile: string): string {
  const result = execSync(
    `whisper-cpp -m ~/.whisper/ggml-large-v2.bin -f ${audioFile} -otxt`,
    { encoding: 'utf-8' }
  );
  return result.trim();
}
```

**Real-time Mode:**
```bash
# Stream from microphone
whisper-cpp -m ~/.whisper/ggml-large-v2.bin --capture --duration 30000
```

---

## Part 2: Custom Voice Server (TTS)

### Cost Comparison

| Provider | Cost/1M chars | Monthly (heavy use) | Quality |
|----------|---------------|---------------------|---------|
| ElevenLabs Pro | $240 (overage) | $50-100 | Excellent |
| **OpenAI TTS** | **$15** | **$3-6** | Very Good |
| **Piper (self-hosted)** | **$0** | **$0** | Good |

**Savings:** 94% with OpenAI, 100% with Piper

### Option A: OpenAI TTS (Quick Win)

**Why OpenAI:**
- $15/1M characters (vs $240 ElevenLabs)
- 6 high-quality voices
- Simple API, same SDK you already use
- ~200ms latency

**Implementation:**
```typescript
// voice-server/backends/openai-tts.ts
import OpenAI from 'openai';

const openai = new OpenAI();

export async function synthesize(text: string, voice = 'nova'): Promise<Buffer> {
  const response = await openai.audio.speech.create({
    model: 'tts-1',        // or 'tts-1-hd' for higher quality
    voice: voice,          // alloy, echo, fable, onyx, nova, shimmer
    input: text,
  });

  return Buffer.from(await response.arrayBuffer());
}
```

**Available Voices:**
- `alloy` - Neutral, balanced
- `echo` - Warm, conversational
- `fable` - British, expressive
- `onyx` - Deep, authoritative
- `nova` - Warm, friendly (recommended for KAI)
- `shimmer` - Clear, bright

### Option B: Piper TTS (Self-Hosted)

**Why Piper:**
- Runs on CPU (no GPU needed)
- Native Apple Silicon support
- MIT license (commercial OK)
- Real-time performance
- Zero ongoing cost

**Installation:**
```bash
# Install Piper
brew install piper

# Or download binary
curl -L https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_macos_aarch64.tar.gz | tar xz

# Download voice model (en_US-lessac-medium recommended)
curl -L -o ~/.piper/en_US-lessac-medium.onnx \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx

curl -L -o ~/.piper/en_US-lessac-medium.onnx.json \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json
```

**HTTP Server Wrapper:**
```typescript
// voice-server/backends/piper.ts
import { execSync } from 'child_process';
import { writeFileSync, readFileSync, unlinkSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

const MODEL = '~/.piper/en_US-lessac-medium.onnx';

export async function synthesize(text: string): Promise<Buffer> {
  const tmpIn = join(tmpdir(), `piper-${Date.now()}.txt`);
  const tmpOut = join(tmpdir(), `piper-${Date.now()}.wav`);

  writeFileSync(tmpIn, text);
  execSync(`cat ${tmpIn} | piper --model ${MODEL} --output_file ${tmpOut}`);

  const audio = readFileSync(tmpOut);
  unlinkSync(tmpIn);
  unlinkSync(tmpOut);

  return audio;
}
```

### Voice Server (Drop-in Replacement)

**Keep the same localhost:8888 interface for PAI compatibility:**

```typescript
// voice-server/server.ts
import Fastify from 'fastify';
import { synthesize as openaiSynth } from './backends/openai-tts';
import { synthesize as piperSynth } from './backends/piper';
import player from 'play-sound';

const fastify = Fastify();
const audioPlayer = player({});

// Backend selection
const BACKEND = process.env.TTS_BACKEND || 'openai'; // 'openai' | 'piper' | 'elevenlabs'

const backends = {
  openai: openaiSynth,
  piper: piperSynth,
};

fastify.post('/notify', async (request, reply) => {
  const { message, voice_id } = request.body as any;

  try {
    const audio = await backends[BACKEND](message);

    // Save to temp file and play
    const tmpFile = `/tmp/voice-${Date.now()}.mp3`;
    require('fs').writeFileSync(tmpFile, audio);
    audioPlayer.play(tmpFile);

    return { status: 'success', message: 'Notification sent' };
  } catch (error) {
    return { status: 'error', message: error.message };
  }
});

fastify.listen({ port: 8888, host: 'localhost' });
```

---

## Implementation Roadmap

### Phase 1: Quick Wins (This Week)

| Task | Effort | Savings |
|------|--------|---------|
| Replace ElevenLabs with OpenAI TTS | 2 hours | 94% cost reduction |
| Create Deepgram browser dictation | 4 hours | Corporate-compatible STT |

### Phase 2: Local Solutions (Next Week)

| Task | Effort | Benefit |
|------|--------|---------|
| Set up whisper.cpp on Mac | 2 hours | Offline dictation |
| Create TypeScript CLI wrapper | 3 hours | Scriptable dictation |

### Phase 3: Full Self-Hosting (Week 3)

| Task | Effort | Benefit |
|------|--------|---------|
| Set up Piper TTS | 4 hours | Zero-cost TTS |
| Unified PAI voice interface | 4 hours | Backend swapping |

---

## File Structure

```
voiceProgram/
├── dictation/
│   ├── browser/
│   │   ├── index.html
│   │   ├── deepgram-client.ts
│   │   └── styles.css
│   └── local/
│       └── whisper-cli.ts
│
├── voice-server/
│   ├── server.ts
│   ├── backends/
│   │   ├── elevenlabs.ts       # Current (keep as fallback)
│   │   ├── openai-tts.ts       # Phase 1
│   │   └── piper.ts            # Phase 3
│   └── config.ts
│
├── package.json
└── README.md
```

---

## Dependencies

```json
{
  "dependencies": {
    "@deepgram/sdk": "^3.0.0",
    "openai": "^4.0.0",
    "fastify": "^4.0.0",
    "play-sound": "^1.1.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0"
  }
}
```

---

## Notes on GitHub Copilot SDK

**The GitHub Copilot SDK does NOT include speech capabilities.**

- No STT (speech-to-text) APIs
- No TTS (text-to-speech) APIs
- No Whisper model access through GitHub Models
- The SDK focuses on agent runtime and text-based AI workflows

**Alternative paths through Microsoft:**
- Azure Speech Services (separate subscription required)
- VS Code Speech Extension (local, free, but VS Code only)

For this project, direct OpenAI and Deepgram APIs are more practical than trying to route through GitHub/Azure.

---

## Cost Summary

| Current | Proposed | Monthly Savings |
|---------|----------|-----------------|
| ElevenLabs (~$50-100/mo) | OpenAI TTS (~$5/mo) | $45-95/mo |
| Apple Dictation (free but bad) | Deepgram ($0.007/min) | Quality improvement |
| - | Local Whisper + Piper | $50-100/mo (all free) |

**Total potential savings: $50-100/month + dramatically improved dictation quality**
