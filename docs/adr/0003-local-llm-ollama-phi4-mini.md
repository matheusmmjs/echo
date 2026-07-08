# ADR 0003 — Limpeza/reescrita de texto: Ollama local, Phi-4-mini

## Status
Aceito

## Contexto
Transcrição bruta do Whisper contém hesitações ("hã", "tipo"), falta pontuação/capitalização, e autocorreções faladas ("vamos terça, não, quarta") que precisam virar só "vamos quarta". Isso exige uma camada de LLM que entenda instrução, não é regex.

Restrição de hardware: Mac M2 com **8GB de RAM unificada** (compartilhada entre CPU, GPU e Neural Engine — todo processo do sistema disputa o mesmo pool).

Modelos considerados:
- **Qwen2.5:7b-instruct-q4** (~4.5GB) — pesado demais pra 8GB somado a macOS + apps abertos (Chrome, editor, etc). Risco real de swap/travamento.
- **Phi-3.5-mini** (~2.2GB) — leve, mas benchmarks 2026 mostram taxa de repetição 5-50x maior que outros modelos e compliance de tamanho de resposta de só 30%. Não confiável pra produção.
- **Phi-4-mini** (3.8B, Q4_K_M, ~2.2GB) — sucessor do Phi-3.5, corrige os problemas de repetição, bate Llama 3.2 3B em MMLU (61.8%), tag oficial `phi4-mini:3.8b-q4_K_M` no Ollama.

Confirmado na prática: RAM da máquina já está sob pressão (~61MB livres observados) só com Chrome + Claude Code abertos — reforça a necessidade de modelo pequeno.

## Decisão
Usar **Ollama** (local, `localhost:11434`, versão atual v0.30.8) rodando **Phi-4-mini Q4_K_M** (`ollama pull phi4-mini:3.8b-q4_K_M`), chamado via HTTP `/api/generate`.

## Consequências
- Cabe confortavelmente em 8GB ao lado de outros apps do dia a dia.
- Qualidade de reescrita é boa pra tarefa repetitiva (limpar texto), mas inferior a modelos maiores em casos ambíguos/complexos (ex: reescrita criativa) — aceitável, essa tarefa é simples por natureza. Observado também: o modelo às vezes reescreve/parafraseia em vez de só limpar (ex: muda "fiz isso que você falou" pra "fiz tudo o que você pediu") — não é crítico pro MVP, mas é candidato a ajuste de prompt futuro se incomodar no uso real.
- Deixa margem de RAM pro objetivo do usuário de ter o agente sempre ativo em background enquanto usa outras ferramentas.

## Atualização: `OLLAMA_KEEP_ALIVE` (teste end-to-end, issue #6/#7)

A decisão original era manter `OLLAMA_KEEP_ALIVE` baixo (poucos minutos) pra liberar RAM rápido quando ocioso. Na prática, isso se mostrou um trade-off ruim pro caso de uso real: um teste end-to-end levou **16 segundos** só na etapa de limpeza (vs ~1-1.5s com o modelo já carregado), porque o modelo tinha sido descarregado por inatividade e precisou recarregar ~2.5GB do disco sob pressão de RAM.

Dado que o objetivo do usuário é um agente de voz **sempre disponível e instantâneo** (não um script batch), decidido trocar pra `OLLAMA_KEEP_ALIVE=30m` — mantém o modelo carregado por meia hora de inatividade antes de descarregar. Troca RAM ociosa (~2.5GB presos por mais tempo) por latência consistente, que é o que importa pra uma ferramenta de ditado usada o dia todo.

Pendência conhecida: hoje isso depende de iniciar o `ollama serve` manualmente com essa flag toda sessão. Automatizar isso (o próprio Echo gerenciar o processo do Ollama, ou um LaunchAgent) é candidato pra um follow-up, não bloqueia o MVP.
