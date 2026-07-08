# ADR 0004 — Inserção de texto: clipboard + paste, com fallback de keystroke

## Status
Aceito

## Contexto
O texto limpo precisa aparecer no campo onde o cursor está, em qualquer app (Slack, VS Code, Notes, navegador), sem integração específica por app. Duas técnicas no macOS:

1. Simular teclado (`CGEvent` keystroke por caractere) — funciona universalmente, mas lento pra textos longos e pode disparar autocomplete/autocorrect indesejado.
2. Clipboard + simular `Cmd+V` — instantâneo, mas pode falhar em campos que bloqueiam paste ou têm handler customizado.

Ambas exigem permissão de **Accessibility** no macOS.

## Decisão
Usar clipboard + paste (`Cmd+V` simulado) como caminho padrão. Se detectarmos que o paste não teve efeito (heurística: conteúdo do campo não mudou), cair no fallback de simulação de keystroke.

## Consequências
- Inserção quase instantânea no caso comum.
- Precisamos de lógica de detecção de falha de paste, que é heurística (não 100% confiável) — aceitar imperfeição no MVP e revisar caso apareçam apps problemáticos no uso real.
- Sobrescrever o clipboard do usuário é um efeito colateral notável — considerar restaurar o clipboard anterior após o paste, se incomodar no uso real.
