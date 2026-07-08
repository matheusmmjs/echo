# ADR 0002 — Transcrição (STT): abstração com duas implementações, whisper.cpp e Apple SpeechAnalyzer

## Status
Aceito, com decisão final de motor padrão registrada (ver "Benchmark e decisão final" abaixo).

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

## Benchmark e decisão final

Rodado com 7 áudios reais gravados durante o desenvolvimento (PT e EN, curtos e longos, incluindo um trecho de silêncio/ruído):

| Amostra | whisper.cpp | Apple SpeechAnalyzer |
|---|---|---|
| jfk.wav (EN, 11s) | 1.86s, correto | 0.73s, correto (pontuação melhor) |
| "me chamo Matheus" | 1.15s, **errou o nome** ("Me chamam Mateus") | 0.42s, acertou |
| Explicação de 23s | 1.30s, correto | 0.38s, correto |
| "teste 1 2 3" | 0.84s, correto | 0.20s, correto |
| "tudo bem" | 0.78s, correto | 0.26s, correto |
| Silêncio/ruído | 0.66s, **alucinou** `[MÚSICA]` | 0.17s, devolveu vazio (correto) |
| "ok testando" | 0.73s, correto | 0.20s, correto |

**Decisão: Apple SpeechAnalyzer é o motor padrão.** Motivos:
- Consistentemente **2-4x mais rápido** que whisper.cpp em toda amostra testada.
- **Não aluciona em silêncio** — whisper.cpp inventou conteúdo (`[MÚSICA]`) numa gravação sem fala real, o que é um risco sério pra um app de ditado (hesitar antes de falar poderia inserir lixo no texto).
- Acertou nomes próprios onde o whisper errou.
- Zero custo de RAM adicional (crítico dado o limite de 8GB).

`whisper.cpp` deixa de ser chamado por padrão e vira **fallback** via `FallbackSTTEngine`: só é acionado se o Apple falhar, der timeout, ou devolver string vazia. Nada do trabalho anterior é descartado — o binário e o modelo continuam instalados, o `WhisperCppEngine` continua existindo e testado, só muda quando ele é chamado. Custo de mantê-lo como fallback é zero enquanto não é acionado (nenhuma RAM/CPU consumida por um motor que não está rodando).
