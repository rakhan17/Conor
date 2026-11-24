<div align="center">

# Conor

**Create. Configure. Experiment.**

A native macOS AI studio for creating model workspaces, fine-tuning language models locally with MLX-LM LoRA, and testing them in a local playground.

[![Build macOS](https://github.com/rakhan17/Conor/actions/workflows/build-macos.yml/badge.svg)](https://github.com/rakhan17/Conor/actions/workflows/build-macos.yml)
[![Platform](https://img.shields.io/badge/platform-macOS-black)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org/)

[![Download for macOS](https://img.shields.io/badge/Download-macOS%20DMG-black?style=for-the-badge&logo=apple)](https://github.com/rakhan17/Conor/releases/latest/download/Conor-macOS.dmg)

**Latest build:** [Download Conor-macOS.dmg](https://github.com/rakhan17/Conor/releases/latest/download/Conor-macOS.dmg) · [All releases](https://github.com/rakhan17/Conor/releases)

</div>

---

## What is Conor?

Conor is a native SwiftUI AI Model Studio. Each model workspace has its own identity, base-model configuration, system instructions, and selectable capabilities.

## Current features

- Native macOS interface with a minimal monochrome design and bottom navigation.
- Create and manage multiple model workspaces.
- Select capabilities: conversation, code, image, vision, writing, and research.
- Configure a base model and system instructions.
- Persist model projects locally.
- Connect to a locally running [Ollama](https://ollama.com/) instance and chat with installed models.
- Run local LoRA fine-tuning through MLX-LM on Apple Silicon.
- Check for signed application updates through Sparkle 2 once update signing is configured.

## Local model training

The Training tab launches the MLX-LM LoRA fine-tuning CLI. This performs actual adapter fine-tuning, not full pretraining from scratch.

Choose a dataset folder containing:

- `train.jsonl` (required)
- `valid.jsonl` (optional)

Each line must be a valid JSON object. MLX-LM supports chat (`messages`), prompt/completion, and text examples. Adapter weights and checkpoints are saved under:

`~/Library/Application Support/Conor/Training/`

Training requires Apple Silicon, Python 3.10+, internet access for the initial runtime/model download, and a compatible MLX model. On an 8 GB Mac, begin with a small quantized model, batch size 1, and a modest dataset. See the [official MLX-LM LoRA guide](https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/LORA.md).

Image generation and dedicated code execution workspaces are not active engines yet.

## In-app updates

Conor integrates Sparkle 2 for signed, in-app updates. A one-time Ed25519 key setup is required before update delivery is enabled. Follow [the setup guide](docs/IN_APP_UPDATES.md) to create the keypair and configure:

- GitHub Actions repository variable: `SPARKLE_PUBLIC_ED_KEY`
- GitHub Actions repository secret: `SPARKLE_EDDSA_PRIVATE_KEY`

Never commit or share the private key. Once configured, tagged releases publish a signed update archive and appcast. Conor checks for updates daily and can install them without a manual GitHub download.

## Requirements

- macOS 13 or later.
- Apple Silicon for MLX-LM training.
- Python 3.10+ for the training runtime.
- [Ollama](https://ollama.com/) for local chat in the Playground.

## Install

1. Click the **Download for macOS** button at the top of this page, or [download Conor-macOS.dmg directly](https://github.com/rakhan17/Conor/releases/latest/download/Conor-macOS.dmg).
2. Open the DMG and drag `Conor.app` to Applications.
3. Launch Conor. For local chat, install and launch Ollama, then download a model such as `llama3.2`.

> The current DMG is ad-hoc signed, not Developer ID notarized. macOS Gatekeeper may require Control-click → Open the first time. Only run builds you trust.

## Build from source

```bash
swift package resolve
swift build -c release
```

## Roadmap

- [x] Native macOS app shell and monochrome UI
- [x] Multiple model workspaces and capability selection
- [x] Local persistence
- [x] Ollama chat integration
- [x] MLX-LM LoRA fine-tuning integration
- [x] Dataset selection and live training process output
- [x] Sparkle update framework integration
- [ ] Signed update key setup and first automatic update release
- [ ] Checkpoint resume, pause, and richer training metrics
- [ ] Dedicated code editor and execution sandbox
- [ ] Image-generation engine integration and preview
- [ ] Model evaluation and comparison
- [ ] Export and import model configurations

## License

No license has been added yet. All rights remain with the repository owner.
