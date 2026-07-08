# ADR 0002 — Transcrição (STT): whisper.cpp local, modelo `small`

## Status
Aceito

## Contexto
Precisamos converter voz em texto. Alternativas: APIs cloud (Deepgram, AssemblyAI, OpenAI) — mais precisas e com streaming, mas custam por minuto e mandam áudio pra fora da máquina; ou execução local.

Requisito inegociável do usuário: tudo local, sem custo recorrente, sem áudio saindo da máquina.

## Decisão
Usar [`whisper.cpp`](https://github.com/ggml-org/whisper.cpp) (`ggml-org/whisper.cpp`, atualmente v1.8.4), instalado via `brew install whisper-cpp`, com aceleração Metal (ligada por padrão em Apple Silicon).

Modelo: `ggml-small` (multilingual), cobre Português e Inglês com boa precisão e latência baixa em M2.

Nesta fase (F1), `whisper.cpp` é chamado como **processo externo** (binário `whisper-cli`) a partir do app Swift — não usamos binding Swift nativo ainda. Simplifica a integração inicial; otimização futura se a latência do processo for um problema.

## Consequências
- Zero custo por uso, 100% privado.
- Precisão um degrau abaixo de modelos cloud state-of-the-art, mas suficiente pra ditado do dia a dia.
- Chamar como processo externo adiciona overhead de I/O (escrever áudio em arquivo temporário, ler stdout) comparado a um binding nativo — aceitável no MVP, revisar em F2/F3 se a latência incomodar.
- Se precisão for insuficiente na prática, trocar para modelo `medium` é só mudar o arquivo `.bin` baixado, sem mudança de arquitetura.
