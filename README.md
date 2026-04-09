# Fish Audio S2 Pro TTS Server

Lean Docker container for Fish Audio S2 Pro TTS with voice cloning, using the `s2.cpp` GGUF inference engine.

## Features
- **Voice cloning** from 5-30 second reference clips
- **Emotion/prosody tags** — `[whisper]`, `(solemn)`, `(warm)`, etc.
- **HTTP API** — simple `/generate` endpoint
- **Q8_0 quantization** — near-lossless quality, fits in 12GB VRAM
- **Pure C++ engine** — no Python, no vLLM, no bloat
- **CUDA support** — runs on NVIDIA GPU

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
    volumes:
      - /mnt/tank/s2-tts/models:/models
      - /mnt/tank/s2-tts/references:/references
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['1']
              capabilities: [gpu]
    restart: unless-stopped
```

> **Note:** Use `device_ids: ['1']` to target a specific GPU (e.g., RTX 3060 12GB).

## API

### Preset Voice
```bash
curl -X POST http://localhost:3030/generate \
  --form "text=Hello, this is a test." \
  --form 'params={"temperature":0.58,"top_p":0.88,"top_k":40}' \
  -o output.wav
```

### Voice Cloning
```bash
curl -X POST http://localhost:3030/generate \
  --form "reference=@reference.wav" \
  --form "reference_text=Transcript of the reference audio." \
  --form "text=Text to synthesize in that voice." \
  --form 'params={"temperature":0.58,"top_p":0.88,"top_k":40}' \
  -o cloned.wav
```

### Emotion Tags
```bash
curl -X POST http://localhost:3030/generate \
  --form "text=(solemn) The Lord is my shepherd. (warm) He makes me lie down in green pastures." \
  -o output.wav
```

## Model Variants
If you want a different quantization, download it and mount it:

| Quant | File Size | VRAM Needed | Quality |
|-------|-----------|-------------|---------|
| Q8_0 | 5.6 GB | ≥ 10 GB | Near-lossless |
| Q6_K | 4.5 GB | 6-9 GB | Good |
| Q5_K_M | 4.0 GB | 5-7 GB | Good |
| Q4_K_M | 3.6 GB | 5-7 GB | Decent |

Download from: https://huggingface.co/rodrigomt/s2-pro-gguf

## Requirements
- NVIDIA GPU with ≥ 10GB VRAM (for Q8_0)
- Docker + Docker Compose with NVIDIA Container Toolkit
- First start takes ~5 minutes (model download during build)