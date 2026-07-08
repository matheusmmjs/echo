import AppKit
import Foundation

// Atalho de debug pra validar o STTEngine isolado, sem precisar do resto do
// app (push-to-talk ainda não existe). Roda com:
//   swift run Echo --test-stt /tmp/jfk.wav en
if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--test-stt" {
    // Arquivos chamados main.swift ganham um tratamento especial do
    // compilador: o código de topo pode usar `await` diretamente, sem
    // precisar envolver em Task{} — o runtime já roda esse arquivo em
    // contexto assíncrono. Mais simples que a combinação Task+semáforo
    // (que também funcionaria, mas é mais código pra o mesmo resultado).
    let fileURL = URL(fileURLWithPath: CommandLine.arguments[2])
    let language = CommandLine.arguments[3]
    let engine = WhisperCppEngine()

    do {
        let text = try await engine.transcribe(audioFileURL: fileURL, language: language)
        print("[\(engine.name)] \(text)")
    } catch {
        print("Erro: \(error)")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// .accessory = agente de menu bar, sem ícone no Dock e sem janela principal.
// Isso é o equivalente em runtime da chave LSUIElement do Info.plist —
// usamos os dois: isso aqui já funciona rodando via `swift run` (sem bundle
// .app), e o Info.plist garante o mesmo comportamento no .app empacotado.
app.setActivationPolicy(.accessory)

app.run()
