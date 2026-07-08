import AppKit
import ApplicationServices

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
    private let cleaner = OllamaCleaner()
    private let injector = TextInjector()
    private let ollamaServer = OllamaServerManager()

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

        requestAccessibilityIfNeeded()

        statusMenuItem.title = "Iniciando Ollama..."
        let ollamaServer = ollamaServer
        Task {
            await ollamaServer.ensureRunning()
            statusMenuItem.title = "Segure Fn e fale"
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        debugLog("applicationWillTerminate chamado")
        ollamaServer.stopIfWeStartedIt()
    }

    // `AXIsProcessTrustedWithOptions` com a opção de prompt: se o Echo
    // ainda não tem permissão de Accessibility, o macOS mostra o alerta
    // do sistema pedindo pra você liberar em System Settings. Sem isso,
    // `CGEvent.post` (usado pelo TextInjector pra simular Cmd+V) não tem
    // efeito nenhum, silenciosamente.
    private func requestAccessibilityIfNeeded() {
        // Valor documentado da constante kAXTrustedCheckOptionPrompt.
        // Usamos a string literal porque a constante em si é um global C
        // não-Sendable, e o Swift 6 barra acesso direto a isso num
        // contexto @MainActor.
        let options: [String: Any] = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
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
        // da closure do Task abaixo — só valores sem estado mutável
        // precisam atravessar essa fronteira.
        let engine = sttEngine
        let cleaner = cleaner
        let injector = injector

        Task {
            // O áudio só serve pra esse momento — apaga depois de usar,
            // sucesso ou falha, pra não acumular lixo em /tmp.
            defer { try? FileManager.default.removeItem(at: fileURL) }
            do {
                let rawText = try await engine.transcribe(audioFileURL: fileURL, language: "pt")
                guard !rawText.isEmpty else {
                    statusMenuItem.title = "Nada reconhecido"
                    return
                }
                debugLog("Transcrição bruta: \(rawText)")

                statusMenuItem.title = "Limpando..."
                let cleanText = (try? await cleaner.clean(rawText: rawText)) ?? rawText
                debugLog("Texto limpo: \(cleanText)")

                injector.paste(cleanText)
                statusMenuItem.title = cleanText
            } catch {
                debugLog("Transcrição falhou: \(error)")
                statusMenuItem.title = "Erro na transcrição"
            }
        }
    }
}
