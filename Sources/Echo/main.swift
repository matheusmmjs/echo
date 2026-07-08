import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// .accessory = agente de menu bar, sem ícone no Dock e sem janela principal.
// Isso é o equivalente em runtime da chave LSUIElement do Info.plist —
// usamos os dois: isso aqui já funciona rodando via `swift run` (sem bundle
// .app), e o Info.plist garante o mesmo comportamento no .app empacotado.
app.setActivationPolicy(.accessory)

app.run()
