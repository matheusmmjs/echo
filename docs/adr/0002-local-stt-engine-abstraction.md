# ADR 0002 — Transcrição (STT): abstração com duas implementações, whisper.cpp e Apple SpeechAnalyzer

## Status
Aceito (substitui a decisão original de usar somente `whisper.cpp`)

## Contexto
Precisamos converter voz em texto, 100% local (requisito inegociável: sem custo recorrente, sem áudio saindo da máquina).

Pesquisa de mercado (2026) comparou candidatos:
- **whisper.cpp** (`ggml-org/whisper.cpp`, v1.9.1) — "padrão-ouro" multilíngue, 99 idiomas, precisão forte em termos técnicos/nomes. Já instalado e validado nesta sessão: transcreveu corretamente um sample de 11s em ~2s usando Metal (GPU M2). Roda como processo externo, consome RAM própria (modelo `small` ~500MB carregado).
- **Apple SpeechAnalyzer** (nativo, disponível no macOS 26.5.1 que o usuário já roda) — zero custo de RAM adicional (roda como serviço do sistema via Neural Engine), API Swift nativa, 55% mais rápido que Whisper Large V3 Turbo segundo a Apple. Contra: fechado, sem controle sobre o modelo, versão nova perdeu o recurso de vocabulário customizado que a API antiga (`SFSpeechRecognizer`) tinha, sem benchmark independente confirmado pra português.
- Parakeet (NVIDIA), Moonshine, Vosk — descartados: Parakeet e Moonshine têm suporte multilíngue fraco (o caso de uso exige PT+EN) e/ou integração Swift imatura; Vosk tem precisão inferior ao Whisper quando há GPU disponível (o M2 tem).

Dado que **RAM de 8GB é o gargalo mais concreto observado** (~61MB livres com apps comuns abertos), a opção nativa da Apple é atraente por não competir por esse orçamento. Mas não há dado de precisão em PT nem experiência prática ainda.

## Decisão
Definir um protocolo Swift `STTEngine` (contrato: recebe buffer de áudio, idioma, devolve texto transcrito) com **duas implementações**:
1. `WhisperCppEngine` — chama o binário `whisper-cli` como processo externo.
2. `AppleSpeechEngine` — usa `SpeechAnalyzer`/`SFSpeechRecognizer` nativo.

O app testa as duas na prática (latência, precisão em PT e EN, uso de RAM real) antes de escolher a padrão. A escolha final vira uma atualização deste ADR quando os testes acontecerem (issue #5/#6).

## Consequências
- Escopo do F1 cresce um pouco (duas implementações em vez de uma), mas o contrato `STTEngine` é pequeno — trocar de motor depois (inclusive adicionar um terceiro) não exige reescrever o pipeline de captura de áudio nem a camada de limpeza (Ollama).
- Decisão de qual motor vira padrão fica baseada em dado real de uso, não em benchmark de terceiros.
- Se a Apple mudar a API do SpeechAnalyzer em versões futuras do macOS (é uma API nova, lançada em 2026), o `AppleSpeechEngine` pode precisar de manutenção — risco aceito, mitigado por manter o `WhisperCppEngine` como alternativa sempre funcional.
