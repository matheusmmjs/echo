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

Configurar `OLLAMA_KEEP_ALIVE` baixo (poucos minutos) para descarregar o modelo da RAM quando ocioso.

## Consequências
- Cabe confortavelmente em 8GB ao lado de outros apps do dia a dia.
- Qualidade de reescrita é boa pra tarefa repetitiva (limpar texto), mas inferior a modelos maiores em casos ambíguos/complexos (ex: reescrita criativa) — aceitável, essa tarefa é simples por natureza.
- Deixa margem de RAM pro objetivo do usuário de ter o agente sempre ativo em background enquanto usa outras ferramentas.
