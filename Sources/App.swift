import SwiftUI
import CoreAudioKit
import ServiceManagement

@main
struct PianoMIDIBridgeApp: App {
    @StateObject private var bridge = MIDIBridge()

    var body: some Scene {
        MenuBarExtra {
            ContentView().environmentObject(bridge)
        } label: {
            Image(systemName: bridge.isRunning && !bridge.devices.isEmpty ? "pianokeys.inverse" : "pianokeys")
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @EnvironmentObject var bridge: MIDIBridge
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var btWindow: CABTLEMIDIWindowController?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pianokeys").font(.title2)
                Text("Piano MIDI Bridge").font(.headline)
                Spacer()
                Toggle("", isOn: Binding(get: { bridge.isRunning },
                                         set: { $0 ? bridge.start() : bridge.stop() }))
                    .toggleStyle(.switch).labelsHidden()
            }

            Divider()

            row("Instrumento (USB)") {
                let instruments = bridge.endpoints.filter { !$0.isBluetooth }
                if instruments.isEmpty {
                    status(false, "Nenhum instrumento encontrado — conecte o cabo USB")
                } else {
                    Picker("", selection: $bridge.pianoID) {
                        ForEach(instruments) { Text($0.name).tag(Optional($0.id)) }
                    }.labelsHidden()
                }
            }

            row("Dispositivo (Bluetooth)") {
                if bridge.devices.isEmpty {
                    status(false, "Aguardando conexão do iPhone/iPad")
                } else {
                    ForEach(bridge.devices) { status(true, $0.name) }
                }
            }

            Divider()

            Toggle("Filtrar clock MIDI (F8)", isOn: $bridge.filterClock)
            Toggle("Filtrar active sensing (FE)", isOn: $bridge.filterActiveSensing)
            Text("Reduz o tráfego no Bluetooth e evita quedas de conexão.")
                .font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 14) {
                stat("→ iPhone", bridge.toDevice)
                stat("→ Piano", bridge.toPiano)
                stat("Filtrados", bridge.filtered)
            }

            Divider()

            Button {
                let c = CABTLEMIDIWindowController()
                c.showWindow(nil)
                c.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                btWindow = c
            } label: {
                Label("Configurar Bluetooth MIDI (Anunciar)…", systemImage: "antenna.radiowaves.left.and.right")
            }

            Toggle("Abrir ao iniciar o Mac", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                    catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
                }

            HStack {
                if let err = bridge.lastError { Text(err).font(.caption).foregroundStyle(.red) }
                Spacer()
                Button("Sair") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    @ViewBuilder private func row<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func status(_ ok: Bool, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(ok ? Color.green : Color.orange).frame(width: 8, height: 8)
            Text(text).lineLimit(1)
        }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value.formatted()).font(.system(.caption, design: .monospaced))
        }
    }
}
