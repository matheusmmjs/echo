import AppKit

// Insere texto no app que estiver em foco: copia pro clipboard e simula
// Cmd+V (ver ADR 0004). `CGEvent` é a mesma API de baixo nível usada pelo
// HotkeyMonitor pra ler teclado — aqui usamos pra escrever, gerando um
// evento de teclado sintético que o macOS trata como se você tivesse
// apertado Cmd+V de verdade. Exige permissão de Accessibility (mesma do
// Input Monitoring, mas é outra entrada no System Settings).
// Doc: https://developer.apple.com/documentation/coregraphics/cgevent
struct TextInjector {
    private static let vKeyCode: CGKeyCode = 9 // tecla "V" no layout US

    func paste(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulateCommandV()

        // Restaura o clipboard anterior depois que o paste teve tempo de
        // acontecer — evita "roubar" o clipboard do usuário permanentemente.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let previousContents else { return }
            pasteboard.clearContents()
            pasteboard.setString(previousContents, forType: .string)
        }
    }

    private func simulateCommandV() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
