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

    // Nesta fase testamos os dois motores lado a lado no mesmo áudio
    // gravado, pra comparar com voz real (ver ADR 0002 / issue #6).
    // Pipeline final (limpeza via Ollama + paste) ainda não está aqui —
    // isso é o próximo passo, depois de validar hotkey + gravação + STT.
    private let whisperEngine = WhisperCppEngine()
    private let appleEngine = AppleSpeechEngine()

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

        // Cópias locais: evita capturar `self` (MainActor-isolated) dentro
        // das closures concorrentes do `async let` abaixo — só os motores
        // (structs, sem estado mutável) precisam atravessar essa fronteira.
        let whisper = whisperEngine
        let apple = appleEngine

        debugLog("1: task starting, file=\(fileURL.path)")
        Task {
            debugLog("2: entered Task, calling whisper")
            let whisperText = await withTimeout(seconds: 20) {
                try await whisper.transcribe(audioFileURL: fileURL, language: "pt")
            }
            debugLog("3: whisper done -> \(whisperText ?? "nil")")

            let appleText = await withTimeout(seconds: 20) {
                try await apple.transcribe(audioFileURL: fileURL, language: "pt")
            }
            debugLog("4: apple done -> \(appleText ?? "nil")")

            let whisperLine = "whisper.cpp: \(whisperText ?? "(falhou/timeout)")"
            let appleLine = "Apple: \(appleText ?? "(falhou/timeout)")"

            debugLog("STT comparison - \(whisperLine) | \(appleLine)")
            statusMenuItem.title = appleText ?? whisperText ?? "Nada reconhecido"
        }
    }
}
