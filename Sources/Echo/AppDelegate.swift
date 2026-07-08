import AppKit

// NSApplicationDelegate: protocolo que recebe eventos do ciclo de vida do
// app (terminou de abrir, vai fechar, etc). Todo app AppKit tem um delegate
// assim — é o "entry point" real depois que a NSApplication sobe.
// Doc: https://developer.apple.com/documentation/appkit/nsapplicationdelegate
// @MainActor: toda a UI do AppKit (NSStatusItem, NSMenu, etc) só pode ser
// tocada na main thread. Marcar a classe inteira garante isso em tempo de
// compilação (Swift 6 checa isso estaticamente) e faz o `Task {}` abaixo
// herdar esse mesmo contexto, em vez de rodar solto numa thread qualquer.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // NSStatusItem: o ícone/menu que fica na barra de menu do macOS
    // (canto superior direito). Precisa ficar guardado numa property,
    // senão o ARC libera o objeto e o ícone some da barra.
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!

    private let hotkey = HotkeyMonitor()
    private let recorder = AudioRecorder()

    // Apple como padrão, whisper.cpp como fallback silencioso — decisão
    // tomada com benchmark real nas gravações desta sessão (ver ADR 0002).
    // Pipeline final (limpeza via Ollama + paste) ainda não está aqui —
    // isso é o próximo passo.
    private let sttEngine: any STTEngine = FallbackSTTEngine(
        primary: AppleSpeechEngine(),
        fallback: WhisperCppEngine()
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "waveform",
            accessibilityDescription: "Echo"
        )

        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: "Segure Fn e fale", action: nil, keyEquivalent: "")
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Sair",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu

        hotkey.onFnDown = { [weak self] in self?.startRecording() }
        hotkey.onFnUp = { [weak self] in self?.stopRecordingAndTranscribe() }
        hotkey.start()
    }

    private func startRecording() {
        do {
            _ = try recorder.start()
            statusItem.button?.image = NSImage(
                systemSymbolName: "waveform.circle.fill",
                accessibilityDescription: "Gravando"
            )
            statusMenuItem.title = "Gravando..."
        } catch {
            statusMenuItem.title = "Erro ao gravar: \(error.localizedDescription)"
        }
    }

    private func stopRecordingAndTranscribe() {
        statusItem.button?.image = NSImage(
            systemSymbolName: "waveform",
            accessibilityDescription: "Echo"
        )
        guard let fileURL = recorder.stop() else { return }
        statusMenuItem.title = "Transcrevendo..."

        // Cópia local: evita capturar `self` (MainActor-isolated) dentro
        // da closure do Task abaixo — só o motor (sem estado mutável)
        // precisa atravessar essa fronteira.
        let engine = sttEngine

        Task {
            do {
                let text = try await engine.transcribe(audioFileURL: fileURL, language: "pt")
                debugLog("Transcrição: \(text)")
                statusMenuItem.title = text.isEmpty ? "Nada reconhecido" : text
            } catch {
                debugLog("Transcrição falhou: \(error)")
                statusMenuItem.title = "Erro na transcrição"
            }
        }
    }
}
