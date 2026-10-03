import SwiftUI
import CoreAudioKit
import ServiceManagement

@main
struct PianoMIDIBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            SteampunkPanel().environmentObject(appDelegate.bridge)
        } label: {
            MenuBarIcon().environmentObject(appDelegate.bridge)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarIcon: View {
    @EnvironmentObject var bridge: MIDIBridge
    var body: some View {
        Image(systemName: bridge.isRunning && !bridge.devices.isEmpty ? "pianokeys.inverse" : "pianokeys")
    }
}

/// Mostra uma janela ao abrir o app (o ícone da barra de menus pode ficar escondido
/// atrás do notch) e garante que só uma cópia do app rode por vez.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor lazy var bridge = MIDIBridge()
    private var window: NSWindow?
    private static let showNotification = Notification.Name("io.github.pianomidibridge.show")

    func applicationWillFinishLaunching(_ notification: Notification) {
        let me = NSRunningApplication.current
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != me.processIdentifier }
        if !others.isEmpty {
            // Já existe uma cópia aberta: pede para ela mostrar a janela e encerra esta.
            DistributedNotificationCenter.default().postNotificationName(Self.showNotification, object: nil,
                                                                         userInfo: nil, deliverImmediately: true)
            exit(0)
        }
    }

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Gera uma imagem do painel sem abrir janela: SNAPSHOT=/caminho.png
        if let out = ProcessInfo.processInfo.environment["SNAPSHOT"] {
            SteampunkPanel.snapshotMode = true
            let r = ImageRenderer(content: SteampunkPanel().environmentObject(bridge))
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: out))
            }
            exit(0)
        }
        #endif
        DistributedNotificationCenter.default().addObserver(forName: Self.showNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.showWindow() }
        }
        showWindow()
    }

    @MainActor func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    @MainActor func showWindow() {
        if window == nil {
            let host = NSHostingController(rootView: SteampunkPanel(showsWindowHint: true, topInset: 18).environmentObject(bridge))
            let w = NSWindow(contentViewController: host)
            w.title = "Piano MIDI Bridge"
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.backgroundColor = NSColor(red: 0.16, green: 0.08, blue: 0.04, alpha: 1)
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

