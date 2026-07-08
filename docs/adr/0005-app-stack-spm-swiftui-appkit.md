# ADR 0005 — Stack do app: Swift Package Manager puro, sem Xcode.app

## Status
Aceito

## Contexto
Ambiente de desenvolvimento verificado: macOS 26.5.1, Swift 6.3.2 disponível via Command Line Tools, mas **Xcode.app não está instalado** (só CLT). Instalar Xcode.app é um download grande (~15GB) só pra rodar um app de menu bar simples.

O app precisa: rodar como agente de menu bar (sem ícone no Dock), pedir permissões de Microfone e Accessibility, e ser distribuído como um `.app` clicável.

## Decisão
Construir via **Swift Package Manager** (executável puro, `swift build`/`swift run`), sem depender de projeto `.xcodeproj`/Xcode.app. UI com SwiftUI (telas de configuração) + AppKit (`NSStatusItem` pro menu bar). `Info.plist` com `LSUIElement=true` (sem ícone no Dock) e chaves de uso de microfone/Accessibility. Um script de bundling empacota o binário SPM num `.app` final.

## Consequências
- Não depende de instalar Xcode.app — funciona no ambiente atual.
- Se o usuário quiser debug visual com breakpoints gráficos no futuro, pode instalar Xcode.app e abrir o pacote SPM nele (SPM é compatível com Xcode) sem reescrever nada.
- Empacotamento em `.app` é manual (script), não automático como um projeto Xcode padrão — mantido simples e documentado.
