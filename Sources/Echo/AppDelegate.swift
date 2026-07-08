import AppKit

// NSApplicationDelegate: protocolo que recebe eventos do ciclo de vida do
// app (terminou de abrir, vai fechar, etc). Todo app AppKit tem um delegate
// assim — é o "entry point" real depois que a NSApplication sobe.
// Doc: https://developer.apple.com/documentation/appkit/nsapplicationdelegate
final class AppDelegate: NSObject, NSApplicationDelegate {
    // NSStatusItem: o ícone/menu que fica na barra de menu do macOS
    // (canto superior direito). Precisa ficar guardado numa property,
    // senão o ARC libera o objeto e o ícone some da barra.
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "waveform",
            accessibilityDescription: "Echo"
        )

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Echo — em desenvolvimento", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Sair",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }
}
