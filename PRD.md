# PRD — Wisprflow Clone (Local, Mac-only)

## Problem Statement

O usuário digita a maior parte do dia em várias ferramentas (mensagens, código, notas, email) e quer ditar por voz em vez de digitar, sem depender de serviços em nuvem que cobram por uso ou mandam áudio pra fora da máquina. Ferramentas como Wisprflow resolvem isso, mas são pagas, fechadas e cloud-based. O usuário quer o mesmo ganho de velocidade (falar é ~5x mais rápido que digitar) rodando 100% local no seu Mac M2 (8GB RAM), sem custo recorrente e sem enviar áudio/texto pra terceiros.

## Solution

Um app de menu bar no macOS que, ao segurar uma tecla (push-to-talk, `Fn`), grava áudio do microfone, transcreve localmente com Whisper (`whisper.cpp` + Metal), limpa/reformata o texto com um LLM local via Ollama (remove hesitações, corrige pontuação, ajusta capitalização) e cola o resultado no app que estiver em foco — funcionando universalmente em qualquer aplicativo Mac, sem integração específica por app.

Fases:
- **F1 (MVP):** push-to-talk → transcrição → limpeza → paste. Este PRD cobre F1.
- **F2:** dicionário pessoal (aprende palavras/nomes recorrentes) + snippets (frases via comando de voz).
- **F3:** detecção do app em foco pra adaptar tom de escrita (formal/casual) + Command Mode (editar texto selecionado por voz).

## User Stories

1. Como usuário, quero segurar uma tecla e falar, para que minha fala vire texto sem precisar digitar.
2. Como usuário, quero soltar a tecla e ver o texto aparecer automaticamente no campo onde meu cursor está, para não precisar copiar/colar manualmente.
3. Como usuário, quero que hesitações ("hã", "tipo", repetições") sejam removidas do texto final, para que o resultado pareça escrito, não uma transcrição bruta.
4. Como usuário, quero que pontuação e capitalização sejam aplicadas automaticamente, para não precisar corrigir manualmente.
5. Como usuário, quero que autocorreções faladas (“vamos terça, não, quarta”) sejam resolvidas para o resultado final correto (“vamos quarta”), para não ter que reformular a frase antes de falar.
6. Como usuário, quero que tudo rode localmente na minha máquina (transcrição e reescrita), para que nenhum áudio ou texto ditado saia do meu Mac.
7. Como usuário, quero que o app não apareça no Dock (agente de menu bar), para que ele fique discreto e sempre disponível em background.
8. Como usuário, quero que o app funcione em qualquer aplicativo (Notes, Slack, VS Code, navegador), para não depender de integrações específicas por app.
9. Como usuário, quero um fallback de digitação simulada caso o paste via clipboard falhe em algum campo específico, para que a ditação nunca fique "presa" sem inserir o texto.
10. Como usuário, quero que o modelo de limpeza (Ollama) seja descarregado da memória quando ocioso, para que o app não deixe meus 8GB de RAM permanentemente ocupados.
11. Como usuário, quero que o app peça as permissões necessárias (Microfone, Accessibility) de forma clara na primeira execução, para entender por que essas permissões são necessárias.
12. Como usuário novo em Swift, quero que decisões técnicas relevantes (APIs novas do macOS, padrões AppKit/SwiftUI) venham acompanhadas de explicação/referência, para aprender a stack enquanto o projeto é construído.
13. Como usuário, quero suporte a Português e Inglês na transcrição e na limpeza de texto, já que são os dois idiomas que uso.
14. Como usuário, quero poder rodar/testar o app via terminal (`swift build`/`swift run` ou `.app` empacotado), já que não tenho o Xcode.app instalado — apenas Command Line Tools.
15. Como usuário, quero que o repositório do projeto exista no GitHub (público, simples) com issues rastreando o progresso, para acompanhar o trabalho fora desta conversa.

## Implementation Decisions

- **Plataforma:** macOS apenas (Apple Silicon, testado em M2/8GB). Sem suporte Windows/Linux/mobile.
- **Transcrição (STT):** `whisper.cpp` compilado com backend Metal, modelo `ggml-small` (multilingual, cobre PT/EN). Chamado como processo externo (binário) a partir do app Swift nesta fase — binding Swift nativo é uma otimização futura, não bloqueia o MVP.
- **Limpeza/reescrita (LLM):** Ollama rodando localmente (`localhost:11434`), modelo **Phi-4-mini** quantizado `Q4_K_M` (~2.2GB), escolhido sobre Qwen2.5-7B (pesado demais pra 8GB de RAM unificada) e sobre Phi-3.5-mini (taxa de repetição alta em benchmarks, não confiável). Chamado via HTTP `/api/generate` com prompt de limpeza (remover hesitação, pontuar, capitalizar, resolver autocorreção falada).
- **Gestão de memória do modelo:** `OLLAMA_KEEP_ALIVE` configurado baixo (ex: alguns minutos) para descarregar o modelo da RAM quando ocioso, dado o limite de 8GB.
- **Ativação da gravação:** push-to-talk segurando a tecla `Fn`, capturada globalmente via `CGEventTap`/`NSEvent` global monitor (requer permissão de Accessibility).
- **Captura de áudio:** `AVAudioEngine`, buffer de áudio em memória enquanto a tecla está pressionada, descartado após transcrição.
- **Inserção de texto no app em foco:** estratégia primária = copiar texto pro clipboard do sistema e simular `Cmd+V`; fallback = simulação de digitação via `CGEvent` keystroke caso o paste não tenha efeito (heurística: verificar se o conteúdo do campo mudou, ou expor comando manual de "forçar digitação").
- **Stack do app:** Swift Package Manager puro (executável), sem depender de `Xcode.app` (ambiente atual só tem Command Line Tools + Swift 6.3.2). UI com SwiftUI (settings/menu) + AppKit (menu bar item via `NSStatusItem`, `LSUIElement=true` no `Info.plist` para não aparecer no Dock). Script de bundling gera um `.app` a partir do binário SPM.
- **Persistência (dicionário pessoal, F2):** SQLite via GRDB.swift, arquivo em `~/Library/Application Support/<app>/`. Fora de escopo do F1, mas schema deve ser previsto na estrutura de dados desde já se for barato.
- **Idiomas:** Português e Inglês (parâmetro de idioma do Whisper e do prompt de limpeza do Ollama).
- **Repositório:** público no GitHub, criado via `gh`, com issues abertas para cada etapa do F1 (uma issue por tarefa/módulo).
- **Permissões macOS necessárias:** Microphone (`NSMicrophoneUsageDescription`), Accessibility (para `CGEventTap` e simulação de paste/keystroke).

## Testing Decisions

- Sem framework de testes automatizados de UI nesta fase (app de sistema, interação real com microfone e outros apps é difícil de mockar de forma útil no F1).
- Testes unitários (via `swift test` / XCTest) para partes isoláveis e determinísticas:
  - Parsing/formatação do prompt enviado ao Ollama (dado texto bruto de entrada, validar prompt montado).
  - Lógica de fallback de inserção de texto (dado "paste falhou", validar que o caminho de fallback é acionado) — testável isolando a lógica de decisão do efeito colateral real de sistema.
- Testes manuais/exploratórios end-to-end obrigatórios antes de considerar o F1 "pronto": ditar em pelo menos 3 apps diferentes (ex: Notes, Slack ou navegador, terminal/VS Code) e validar transcrição + limpeza + inserção.
- Não testar comportamento do Whisper/Ollama em si (são dependências externas já testadas por seus mantenedores) — testar apenas a integração (chamada, parsing de resposta, tratamento de erro/timeout).

## Out of Scope

- Windows, Linux, iOS, Android.
- Dicionário pessoal e snippets (F2).
- Detecção de app em foco / adaptação de tom e Command Mode (F3).
- Suporte a mais de 2 idiomas.
- Sincronização entre dispositivos, contas de usuário, telemetria/analytics.
- Auditoria geral de performance do Mac (login items, limpeza de disco) — tratada como iniciativa separada após o F1 funcionar.
- Empacotamento para distribuição/App Store (assinatura, notarização) — uso é local e pessoal.
- Binding Swift nativo do whisper.cpp (chamado como processo externo por enquanto).

## Further Notes

- Ambiente verificado nesta sessão: macOS 26.5.1, Apple M2, 8GB RAM, 41GB disco livre, Swift 6.3.2 (Command Line Tools, sem Xcode.app), Homebrew instalado, Ollama e whisper.cpp ainda não instalados.
- Sinal real observado: RAM já sob pressão (~61MB livres) com Chrome + Claude Code abertos — validar uso de memória do F1 rodando ao lado de apps comuns do usuário, não isolado.
- Usuário é novo em Swift — decisões de implementação devem vir acompanhadas de explicação/referência ao introduzir conceitos novos de SwiftUI/AppKit/APIs do macOS.
