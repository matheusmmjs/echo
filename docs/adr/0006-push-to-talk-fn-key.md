# ADR 0006 — Ativação: push-to-talk segurando `Fn`

## Status
Aceito

## Contexto
Precisamos de um jeito de ligar/desligar a gravação de voz. Duas opções: push-to-talk (segura tecla, solta = para) ou toggle (aperta uma vez pra começar, de novo pra parar).

## Decisão
Push-to-talk segurando a tecla `Fn`, capturada globalmente via `CGEventTap`/`NSEvent` global monitor (funciona mesmo com o app em background, exige permissão de Accessibility — a mesma já necessária pro paste, ADR 0004).

## Consequências
- Comportamento previsível tipo walkie-talkie: nunca "esquece" gravando.
- Segue o padrão do Wisprflow original, familiar pra quem já usou.
- Tecla fixa (`Fn`) no MVP; tecla configurável fica pra depois, se incomodar no uso real.
