import AppKit

// Monitora a tecla Fn/Globe globalmente (mesmo com outro app em foco).
// A tecla Fn não gera keyDown/keyUp normal — ela aparece como uma mudança
// nas "modifier flags" do teclado (igual Shift/Ctrl/Cmd). Por isso
// escutamos `.flagsChanged` e comparamos o antes/depois da flag `.function`.
//
// Exige permissão de **Input Monitoring** (System Settings > Privacy &
// Security > Input Monitoring). Diferente de Accessibility: não tem prompt
// automático — o macOS só lista o app ali na primeira vez que ele tenta
// instalar um monitor global, e você libera manualmente.
// Doc: https://developer.apple.com/documentation/appkit/nsevent/1535472-addglobalmonitorforevents
final class HotkeyMonitor {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isFnPressed = false

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        // Monitor local: garante que também funcione quando o próprio Echo
        // (ex: um painel de configurações futuro) estiver em foco.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let fnNow = event.modifierFlags.contains(.function)
        guard fnNow != isFnPressed else { return }
        isFnPressed = fnNow
        if fnNow {
            onFnDown?()
        } else {
            onFnUp?()
        }
    }
}
