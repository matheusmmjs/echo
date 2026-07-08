# Glossário

- **STT (Speech-to-Text):** conversão de áudio de voz em texto transcrito. Aqui: `whisper.cpp`.
- **Whisper / whisper.cpp:** modelo de transcrição de voz da OpenAI; `whisper.cpp` é a porta em C/C++ que roda localmente, com aceleração Metal em Apple Silicon.
- **Ollama:** runtime local pra rodar LLMs open-source via API HTTP (`localhost:11434`), sem depender de serviço cloud.
- **Phi-4-mini:** modelo de linguagem pequeno (3.8B parâmetros) da Microsoft, usado aqui pra limpar/reformatar o texto transcrito.
- **Quantização (Q4_K_M):** técnica que reduz a precisão numérica dos pesos do modelo pra ocupar menos memória/disco, com pequena perda de qualidade. Q4_K_M é um bom equilíbrio tamanho/qualidade.
- **Push-to-talk:** modo de gravação onde você segura uma tecla pra gravar e solta pra parar (oposto de "toggle").
- **RAM unificada (Unified Memory):** arquitetura da Apple Silicon onde CPU, GPU e Neural Engine compartilham o mesmo pool de memória física — todo processo compete pelo mesmo total.
- **`CGEventTap`:** API de baixo nível do macOS pra capturar eventos de teclado/mouse globalmente (mesmo fora do app), usada aqui pro hotkey `Fn` e simulação de paste/keystroke.
- **`NSStatusItem`:** API do AppKit pra colocar um ícone/menu na barra de menu do macOS (menu bar).
- **`LSUIElement`:** chave do `Info.plist` que faz o app rodar sem ícone no Dock (agente de background).
- **Accessibility (permissão macOS):** permissão de sistema necessária pra apps que capturam eventos globais de teclado ou controlam outros apps (paste, keystroke simulado).
- **F1/F2/F3:** fases do projeto — F1 (MVP: dictação+limpeza+inserção), F2 (dicionário pessoal + snippets), F3 (detecção de app em foco + Command Mode).
