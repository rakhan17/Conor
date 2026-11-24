<div align="center">

# Conor

**Create. Configure. Experiment.**

A native macOS workspace for creating and managing AI model projects, configuring capabilities, and testing local models.

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
- GitHub Actions builds a macOS DMG on pushes and publishes the DMG when a v* tag is pushed.

### Training status

The current build does **not** fine-tune model weights yet. It stores training configuration and dataset selection without pretending to run a training job. A real training engine, such as MLX-LM/LoRA on Apple Silicon, is a planned integration. Image generation and code-specific workspaces are also planned integrations, not active engines in this first build.

## Requirements

- macOS 13 or later.
- Apple Silicon or Intel Mac capable of running the selected local runtime.
- [Ollama](https://ollama.com/) for local chat in the Playground.

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
