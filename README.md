# echo

Clone local do [Wisprflow](https://wisprflow.ai/) — dictação por voz universal pro macOS, rodando 100% na máquina, sem cloud.

Fala vira texto: transcrição local com Whisper (`whisper.cpp`), limpeza e formatação com um LLM local (Ollama), e o texto é inserido automaticamente no app que estiver em foco.

## Status

Em desenvolvimento — Fase 1 (MVP): push-to-talk → transcrição → limpeza → inserção de texto.

Ver [PRD.md](PRD.md) pras decisões de produto e arquitetura.

## Stack

- macOS (Apple Silicon)
- Swift Package Manager (sem Xcode.app)
- Whisper local (`whisper.cpp` + Metal)
- Ollama local (Phi-4-mini)

## Requisitos

- Mac Apple Silicon, 8GB+ RAM
- [Ollama](https://ollama.com) instalado
- Homebrew
