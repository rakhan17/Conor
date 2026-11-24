<div align="center">

# Conor

**Create. Configure. Experiment.**

A native macOS AI studio for creating model workspaces, fine-tuning language models locally with MLX-LM LoRA, and testing them in a local playground.

[![Build macOS](https://github.com/rakhan17/Conor/actions/workflows/build-macos.yml/badge.svg)](https://github.com/rakhan17/Conor/actions/workflows/build-macos.yml)
[![Platform](https://img.shields.io/badge/platform-macOS-black)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org/)

[**⬇ Download for macOS**](https://github.com/rakhan17/Conor/releases/latest/download/Conor-macOS.dmg)

</div>

---

## What is Conor?

Conor is an AI Model Studio concept built as a native SwiftUI application. It gives each model its own identity, base-model configuration, system instructions, and a multi-select set of capabilities.

### Current build

- Native macOS interface with a monochrome design.
- Create and manage multiple model workspaces.
- Choose multiple capabilities: conversation, code, image, vision, writing, and research.
- Configure a base model, system instructions, and epoch settings.
- Persist model projects locally.
- Connect to a locally running [Ollama](https://ollama.com/) instance and chat with installed models.
- Select a JSON or text dataset and save training configuration.
- Sparkle 2 is integrated for signed in-app updates. Once the one-time signing keys are configured, Conor checks for updates daily and can download and install releases without a manual GitHub download.\n- GitHub Actions builds a macOS DMG on pushes and publishes the DMG when a v* tag is pushed.

### Training status

The Training tab now launches the real MLX-LM LoRA fine-tuning CLI. It expects a local dataset directory containing `train.jsonl` and optionally `valid.jsonl`. Each JSONL line must be one valid JSON object. MLX-LM supports chat (`messages`), prompt/completion, and text examples. Trained adapter weights are written under `~/Library/Application Support/Conor/Training/`. This is adapter fine-tuning, not full pretraining from scratch.\n\nTraining requires Apple Silicon and a compatible MLX model. Start with a small quantized model, batch size 1, and a modest dataset on Macs with 8 GB unified memory. MLX-LM's official guide documents the supported commands and dataset formats: [MLX-LM LoRA guide](https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/LORA.md). Image generation and code-specific execution workspaces are not active engines yet.

## In-app updates\n\nConor uses Sparkle 2 with Ed25519-signed update archives. A one-time key setup is required before secure updates can be delivered. Follow [the in-app update setup guide](docs/IN_APP_UPDATES.md) to generate the keypair and configure the public repository variable and private Actions secret. The private key must never be committed.\n\n## Requirements

- macOS 13 or later.
- Apple Silicon or Intel Mac capable of running the selected local runtime.
- Apple Silicon Mac for MLX-LM training.\n- Python 3.10+ and internet access for the first MLX-LM installation/model download.\n- [Ollama](https://ollama.com/) for local chat in the Playground.

## Install

1. Download Conor-macOS.dmg from the [latest release](https://github.com/rakhan17/Conor/releases/latest/download/Conor-macOS.dmg).
2. Open the DMG and drag Conor.app to Applications.
3. Open Conor. For local chat, install and launch Ollama, then download a model such as llama3.2.

> This initial DMG is ad-hoc signed, not Developer ID notarized. macOS Gatekeeper may require you to use Control-click → Open the first time. Do not bypass security prompts unless you trust the build source.

## Build from source

    swift build -c release

## Roadmap

- [x] Native macOS app shell and monochrome UI
- [x] Multiple model workspaces and capability selection
- [x] Local persistence
- [x] Ollama chat integration
- [x] Training configuration and dataset selection
- [ ] MLX-LM fine-tuning with LoRA and real epoch/loss reporting
- [ ] Checkpoint, pause, resume, and cancel controls
- [ ] Dedicated code editor and execution sandbox
- [ ] Image-generation engine integration and preview
- [ ] Model evaluation and comparison
- [ ] Export and import model configurations

## License

No license has been added yet. All rights remain with the repository owner.
