# ADR 0001 — Plataforma: macOS apenas (Apple Silicon)

## Status
Aceito

## Contexto
Wisprflow original roda em Mac, Windows, iOS e Android. O objetivo aqui é um clone pessoal, rodando primeiro na máquina do próprio usuário: MacBook com Apple Silicon M2, 8GB RAM.

## Decisão
Suportar apenas macOS (Apple Silicon). Sem Windows, Linux, iOS ou Android nesta fase.

## Consequências
- Podemos usar APIs nativas do macOS sem camada de abstração cross-platform (Accessibility API, AVAudioEngine, NSStatusItem, Metal via whisper.cpp).
- Simplifica drasticamente o escopo de engenharia (não precisa de UI Automation do Windows, por exemplo, pra injeção de texto).
- Se um dia vira produto multi-plataforma, exigirá reescrever a camada de injeção de texto e captura de hotkey — aceitável, não é objetivo agora.
