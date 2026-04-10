# Fish Audio S2 Pro TTS Server

Lean Docker container for Fish Audio S2 Pro TTS with voice cloning and emotion control, using the [s2.cpp](https://github.com/rodrigomatta/s2.cpp) GGUF inference engine.

## Features

- **Voice cloning** from 5-30 second reference clips
- **Emotion/prosody tags** — `[bracket]` syntax with natural language descriptions
- **HTTP API** — simple `/generate` endpoint with server mode
- **Q8_0 quantization** — near-lossless quality, fits in 12GB VRAM
- **Pure C++ engine** — no Python, no vLLM, no bloat
- **CUDA support** — runs on NVIDIA GPU

## Links

- **Docker Image:** `ghcr.io/orrinwitt/s2-tts:latest`
- **GGUF Models:** [rodrigomt/s2-pro-gguf](https://huggingface.co/rodrigomt/s2-pro-gguf)
- **s2.cpp Engine:** [rodrigomatta/s2.cpp](https://github.com/rodrigomatta/s2.cpp)
- **Fish Audio S2 Pro:** [fishaudio/s2-pro](https://huggingface.co/fishaudio/s2-pro)
- **Fish Audio Docs:** [speech.fish.audio](https://speech.fish.audio/)

## Quick Start

```yaml
services:
  s2-tts:
    container_name: s2-tts
    image: ghcr.io/orrinwitt/s2-tts:latest
    ports:
      - "3030:3030"
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - CUDA_DEVICE=0
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['1']
              capabilities: [gpu]
    restart: unless-stopped
```

> **Note:** The Q8_0 model and tokenizer are baked into the image — no volume mounts needed for models. Use `device_ids: ['1']` to target a specific GPU (e.g., RTX 3060 12GB).

## API

### Basic Synthesis (No Voice Cloning)
```bash
curl -X POST http://localhost:3030/generate \
  --form "text=Hello, this is a test." \
  -o output.wav
```

### Voice Cloning
```bash
curl -X POST http://localhost:3030/generate \
  --form "reference=@reference.wav" \
  --form "reference_text=Transcript of the reference audio." \
  --form "text=Text to synthesize in that voice." \
  -o cloned.wav
```

### Emotion Tags (S2-Pro Bracket Syntax)
```bash
curl -X POST http://localhost:3030/generate \
  --form "text=[excited] What a remarkable day! [skeptical] Hmm, I'm not so sure about that. [whispering] But between you and me, something splendid is about to happen." \
  -o output.wav
```

### With Parameters
```bash
curl -X POST http://localhost:3030/generate \
  --form "reference=@reference.wav" \
  --form "reference_text=Transcript of the reference audio." \
  --form "text=Text to synthesize." \
  --form 'params={"max_new_tokens":4096,"temperature":0.58,"top_p":0.88,"top_k":40}' \
  -o output.wav
```

## Emotion Tags

S2-Pro uses **`[bracket]` syntax** with natural language descriptions — NOT `(parentheses)` which is the S1 format.

### Supported Tags
The model accepts free-form natural language descriptions. Some examples:

**Emotions:** `[excited]` `[curious]` `[skeptical]` `[frustrated]` `[delighted]` `[grateful]` `[confident]` `[sad]` `[angry]` `[surprised]`

**Tone:** `[whispering]` `[shouting]` `[soft tone]` `[in a hurry tone]`

**Effects:** `[laughing]` `[chuckling]` `[sighing]` `[sobbing]` `[panting]`

**Natural language:** `[speaking slowly and solemnly]` `[with deep sincerity]` `[with quiet confidence]`

### Tips
- **Use contrasting emotions** for dynamic range — avoid same-sounding tags in sequence
- Tags go **before** the sentence they modify
- One emotion per sentence works best
- Overusing tags in short text sounds unnatural

## Text Formatting Rules

- ✅ Use plain sentences with **periods**
- ❌ **No semicolons** — causes gibberish/repetition
- ❌ **No `(parentheses)`** in text — confuses tokenizer, causes early cutoff
- ✅ Long text works fine with clean punctuation

## Audio Output

The server outputs **32-bit float WAV at 44100Hz**. Convert to 16-bit PCM for playback:

```python
import wave, numpy as np

with open('output.wav', 'rb') as f:
    data = f.read()

data_idx = data.find(b'data')
data_size = int.from_bytes(data[data_idx+4:data_idx+8], 'little')
audio_float = np.frombuffer(data[data_idx+8:data_idx+8+data_size], dtype=np.float32)
audio_float = audio_float / np.max(np.abs(audio_float)) * 0.95
audio_int16 = (audio_float * 32767).astype(np.int16)

with wave.open('output_pcm.wav', 'wb') as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(44100)
    wf.writeframes(audio_int16.tobytes())
```

## Model Variants

The default image includes Q8_0. To use a different quantization, download from [rodrigomt/s2-pro-gguf](https://huggingface.co/rodrigomt/s2-pro-gguf) and mount it:

```yaml
volumes:
  - /path/to/your/s2-pro-q6_k.gguf:/models/s2-pro-q8_0.gguf
  - /path/to/tokenizer.json:/models/tokenizer.json
```

| Quant | File Size | VRAM Needed | Quality |
|-------|-----------|-------------|---------|
| Q8_0 | 5.6 GB | ≥ 10 GB | Near-lossless |
| Q6_K | 4.5 GB | 6-9 GB | Good |
| Q5_K_M | 4.0 GB | 5-7 GB | Good |
| Q4_K_M | 3.6 GB | 5-7 GB | Decent |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `text` | "Hello world" | Text to synthesize |
| `reference` | — | Reference audio file (WAV/MP3, 5-30 seconds) |
| `reference_text` | — | Transcript of reference audio (required if reference provided) |
| `params` | — | JSON: `max_new_tokens`, `temperature`, `top_p`, `top_k`, `min_tokens_before_end` |

## Requirements

- NVIDIA GPU with ≥ 10GB VRAM (for Q8_0)
- Docker + Docker Compose with NVIDIA Container Toolkit
- No external model downloads needed — everything is baked into the image

## License

- **s2.cpp engine:** MIT License
- **S2-Pro model weights:** [Fish Audio Research License](https://huggingface.co/fishaudio/s2-pro/blob/main/LICENSE.md) — free for research and non-commercial use
- **GGUF quantizations:** [Fish Audio Research License](https://huggingface.co/rodrigomt/s2-pro-gguf/blob/main/LICENSE.md)