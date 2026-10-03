// Interface no estilo amplificador valvulado steampunk:
// moldura de madeira, painel de latão rebitado, válvulas, VU meters e chaves de alavanca.
import SwiftUI
import ServiceManagement

// MARK: - Paleta e tipografia

enum Brass {
    static let light = Color(red: 0.93, green: 0.78, blue: 0.47)
    static let mid = Color(red: 0.76, green: 0.58, blue: 0.29)
    static let dark = Color(red: 0.46, green: 0.32, blue: 0.13)
    static let copper = Color(red: 0.72, green: 0.42, blue: 0.22)
    static let ink = Color(red: 0.20, green: 0.12, blue: 0.05)
    static let woodLight = Color(red: 0.36, green: 0.20, blue: 0.10)
    static let woodDark = Color(red: 0.16, green: 0.08, blue: 0.04)
    static let glow = Color(red: 1.0, green: 0.55, blue: 0.15)
    static let cream = Color(red: 0.96, green: 0.91, blue: 0.78)

    static let plate = LinearGradient(colors: [light, mid, Color(red: 0.85, green: 0.68, blue: 0.38), dark.opacity(0.9)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    static let metal = LinearGradient(colors: [light, mid, dark], startPoint: .top, endPoint: .bottom)
}

extension Font {
    static func engraved(_ size: CGFloat) -> Font { .custom("Copperplate", size: size).weight(.bold) }
    static func typewriter(_ size: CGFloat) -> Font { .custom("American Typewriter", size: size) }
}

/// Texto "gravado" no latão: escuro com realce claro abaixo.
struct Engraved: View {
    let text: String
    var size: CGFloat = 11
    init(_ text: String, size: CGFloat = 11) { self.text = text; self.size = size }
    var body: some View {
        Text(text).font(.engraved(size)).tracking(1.2)
            .foregroundStyle(Brass.ink.opacity(0.85))
            .shadow(color: .white.opacity(0.45), radius: 0, x: 0, y: 1)
    }
}

// MARK: - Painel principal

struct SteampunkPanel: View {
    /// Usado só para gerar a imagem do README (ImageRenderer não desenha menus nativos).
    static var snapshotMode = false
    /// Só no snapshot: força o estado "aguardando iPhone" para conferir o layout das dicas.
    static var snapshotWaiting = false
    @EnvironmentObject var bridge: MIDIBridge
    @AppStorage("lang") private var langRaw = Lang.current.rawValue
    private var lang: Lang { Lang(rawValue: langRaw) ?? .en }
    private var t: Strings { .of(lang) }
    var showsWindowHint = false
    /// Espaço extra no topo quando o painel ocupa a janela com barra de título transparente.
    var topInset: CGFloat = 0
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var active: Bool { bridge.isRunning }

    var body: some View {
        VStack(spacing: 14) {
            header
            HStack(alignment: .bottom, spacing: 10) {
                VUMeter(label: t.toPhone, rate: bridge.rateToDevice, powered: active)
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        VacuumTube(power: active ? 0.45 + activity(bridge.rateToDevice) * 0.55 : 0)
                        VacuumTube(power: active ? 0.45 + activity(bridge.rateToPiano) * 0.55 : 0)
                    }
                    Engraved(t.tubes, size: 8)
                }
                VUMeter(label: t.toPiano, rate: bridge.rateToPiano, powered: active)
            }
            stations
            switches
            footer
        }
        .padding(18)
        .background(BrassPlate())
        .padding(12)
        .padding(.top, topInset)
        .background(WoodFrame())
        .frame(width: 470)
        .preferredColorScheme(.dark)
    }

    private func activity(_ rate: Double) -> Double { min(1, log10(1 + rate) / log10(1 + 2000)) }

    // Cabeçalho com engrenagens
    private var header: some View {
        HStack(spacing: 10) {
            Gear(teeth: 12, spinning: active, speed: 1).frame(width: 34, height: 34)
            VStack(spacing: 2) {
                Text("PIANO MIDI BRIDGE").font(.engraved(20)).tracking(2)
                    .foregroundStyle(Brass.ink)
                    .shadow(color: .white.opacity(0.5), radius: 0, x: 0, y: 1)
                Text(t.subtitle).font(.typewriter(9.5))
                    .foregroundStyle(Brass.ink.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            Gear(teeth: 9, spinning: active, speed: -1.4).frame(width: 26, height: 26)
            MasterSwitch(t: t, isOn: Binding(get: { bridge.isRunning }, set: { $0 ? bridge.start() : bridge.stop() }))
        }
    }

    // Estações: instrumento e dispositivo, com lâmpadas-piloto
    private var stations: some View {
        let instruments = bridge.endpoints.filter { !$0.isBluetooth }
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                PilotLamp(color: bridge.pianoID != nil ? .green : .red, lit: active)
                Engraved(t.instrument, size: 9).frame(width: 92, alignment: .leading)
                if instruments.isEmpty {
                    NamePlate(t.connectUSB, dim: true)
                } else if Self.snapshotMode {
                    NamePlate((bridge.pianoName ?? t.select) + "  ▾")
                } else {
                    Menu {
                        ForEach(instruments) { i in Button(i.name) { bridge.pianoID = i.id } }
                    } label: {
                        NamePlate((bridge.pianoName ?? t.select) + "  ▾")
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                PilotLamp(color: transmitterColor, lit: active, blinking: isAdvertising && !bridge.isLinked)
                Engraved(t.transmitter, size: 9).frame(width: 92, alignment: .leading)
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Brass.cream.opacity(0.8))
                    if Self.snapshotMode {
                        Text(bridge.bleName).font(.typewriter(11.5)).foregroundStyle(Brass.cream)
                            .frame(width: 150, alignment: .leading)
                    } else {
                        TextField("", text: $bridge.bleName)
                            .textFieldStyle(.plain).font(.typewriter(11.5)).foregroundStyle(Brass.cream)
                            .frame(width: 150)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.12, green: 0.07, blue: 0.04)))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Brass.mid, lineWidth: 1.2))
                .help(t.editNameHelp)
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                PilotLamp(color: bridge.isLinked ? .green : .orange, lit: active)
                Engraved(t.receiver, size: 9).frame(width: 92, alignment: .leading)
                receiverPlate
                Spacer(minLength: 0)
            }
            if active, let hint = guidance {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hint).font(.typewriter(10.5)).foregroundStyle(Brass.ink.opacity(0.9))
                    Text(t.notFoundHint).font(.typewriter(9.5)).foregroundStyle(Brass.ink.opacity(0.65))
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 28)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Brass.ink.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Brass.dark.opacity(0.6), lineWidth: 1)))
    }

    private var isAdvertising: Bool {
        if case .advertising = bridge.bleStatus { return true }
        return false
    }

    private var transmitterColor: Color {
        switch bridge.bleStatus {
        case .advertising, .connected: return .green
        case .starting, .idle: return .orange
        default: return .red
        }
    }

    @ViewBuilder private var receiverPlate: some View {
        switch bridge.bleStatus {
        case .off where !bridge.isLinked: NamePlate(t.btOff, dim: true)
        case .unsupported where !bridge.isLinked: NamePlate(t.btUnsupported, dim: true)
        case .unauthorized where !bridge.isLinked:
            HStack(spacing: 6) {
                NamePlate(t.btUnauthorized, dim: true)
                BrassButton(title: t.openSettings, systemImage: "gearshape") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!)
                }
            }
        default:
            if case .connected = bridge.bleStatus { NamePlate(t.phoneConnected) }
            else if let d = bridge.devices.first { NamePlate(d.name) }
            else { NamePlate(t.waitingPhone, dim: true) }
        }
    }

    /// Próximo passo para o usuário, enquanto o iPhone não conectou.
    private var guidance: String? {
        guard Self.snapshotWaiting || (!bridge.isLinked && isAdvertising) else { return nil }
        return String(format: t.connectHint, bridge.bleName)
    }

    // Chaves de alavanca e contador Nixie
    private var switches: some View {
        HStack(alignment: .top, spacing: 18) {
            ToggleLever(title: t.filterClock, isOn: $bridge.filterClock)
            ToggleLever(title: t.filterSensing, isOn: $bridge.filterActiveSensing)
            ToggleLever(title: t.launchAtLogin, isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                    catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
                }
            Spacer(minLength: 0)
            VStack(spacing: 5) {
                NixieCounter(value: bridge.filtered, digits: 7, powered: active)
                Engraved(t.bytesFiltered, size: 8)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                LanguageSelector(title: t.language, lang: $langRaw)
                Spacer(minLength: 4)
                BrassButton(title: t.quit, systemImage: "power") { NSApp.terminate(nil) }
            }
            if showsWindowHint {
                Text(t.windowHint)
                    .font(.typewriter(9.5)).foregroundStyle(Brass.ink.opacity(0.75))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            if let err = bridge.lastError {
                Text(err).font(.typewriter(10)).foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Moldura e placa

struct WoodFrame: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(LinearGradient(colors: [Brass.woodLight, Brass.woodDark, Brass.woodLight.opacity(0.9), Brass.woodDark],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                // veios da madeira
                Canvas { ctx, size in
                    for i in 0..<28 {
                        let y = CGFloat(i) / 28 * size.height
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addCurve(to: CGPoint(x: size.width, y: y + CGFloat((i % 5) - 2) * 3),
                                   control1: CGPoint(x: size.width * 0.3, y: y + CGFloat(i % 3) * 4 - 4),
                                   control2: CGPoint(x: size.width * 0.7, y: y - CGFloat(i % 4) * 3 + 4))
                        ctx.stroke(p, with: .color(.black.opacity(0.18)), lineWidth: i % 4 == 0 ? 1.4 : 0.6)
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 14))
            )
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.black.opacity(0.6), lineWidth: 2))
    }
}

struct BrassPlate: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Brass.plate)
            // textura escovada
            Canvas { ctx, size in
                for i in stride(from: 0, to: size.height, by: 2) {
                    var p = Path(); p.move(to: CGPoint(x: 0, y: i)); p.addLine(to: CGPoint(x: size.width, y: i))
                    ctx.stroke(p, with: .color(.white.opacity(Int(i) % 6 == 0 ? 0.06 : 0.02)), lineWidth: 1)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 8))
            RoundedRectangle(cornerRadius: 8).stroke(Brass.dark, lineWidth: 2)
            RoundedRectangle(cornerRadius: 6).inset(by: 5).stroke(Brass.ink.opacity(0.25), lineWidth: 0.8)
            GeometryReader { g in
                ForEach(0..<4) { i in
                    Rivet().position(x: i % 2 == 0 ? 11 : g.size.width - 11, y: i < 2 ? 11 : g.size.height - 11)
                }
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
    }
}

struct Rivet: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Brass.light, Brass.mid, Brass.dark], center: .init(x: 0.35, y: 0.3),
                                 startRadius: 0, endRadius: 6))
            .frame(width: 9, height: 9)
            .shadow(color: .black.opacity(0.5), radius: 1, x: 0.5, y: 1)
    }
}

// MARK: - Engrenagem

struct GearShape: Shape {
    var teeth: Int
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2, inner = outer * 0.78
        var p = Path()
        let step = .pi * 2 / Double(teeth)
        for i in 0..<teeth {
            let a = Double(i) * step
            let pts: [(Double, CGFloat)] = [(a, inner), (a + step * 0.15, outer), (a + step * 0.45, outer), (a + step * 0.6, inner)]
            for (j, (ang, r)) in pts.enumerated() {
                let pt = CGPoint(x: c.x + CGFloat(cos(ang)) * r, y: c.y + CGFloat(sin(ang)) * r)
                if i == 0 && j == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: c.x - outer * 0.28, y: c.y - outer * 0.28, width: outer * 0.56, height: outer * 0.56))
        return p
    }
}

struct Gear: View {
    let teeth: Int
    let spinning: Bool
    let speed: Double
    var body: some View {
        TimelineView(.animation(paused: !spinning)) { t in
            let angle = spinning ? t.date.timeIntervalSinceReferenceDate * 30 * speed : 0
            GearShape(teeth: teeth)
                .fill(LinearGradient(colors: [Brass.copper, Brass.dark], startPoint: .top, endPoint: .bottom), style: FillStyle(eoFill: true))
                .overlay(GearShape(teeth: teeth).stroke(Brass.ink.opacity(0.6), lineWidth: 0.8))
                .rotationEffect(.degrees(angle.truncatingRemainder(dividingBy: 360)))
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
        }
    }
}

// MARK: - Válvula

struct VacuumTube: View {
    /// 0 = desligada, 1 = brilho máximo
    let power: Double
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: power == 0)) { t in
            let s = t.date.timeIntervalSinceReferenceDate
            let flicker = power == 0 ? 0 : 0.06 * sin(s * 23) + 0.04 * sin(s * 7.3)
            let glow = max(0, power + flicker)
            ZStack(alignment: .bottom) {
                // halo
                Ellipse().fill(Brass.glow.opacity(glow * 0.55)).frame(width: 46, height: 60).blur(radius: 14).offset(y: -22)
                VStack(spacing: 0) {
                    ZStack {
                        // envelope de vidro
                        UnevenRoundedRectangle(topLeadingRadius: 15, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 15)
                            .fill(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.05), .white.opacity(0.14)],
                                                 startPoint: .leading, endPoint: .trailing))
                        // placas internas
                        HStack(spacing: 4) {
                            ForEach(0..<2) { _ in
                                RoundedRectangle(cornerRadius: 1).fill(Color(white: 0.35)).frame(width: 7, height: 30)
                            }
                        }.offset(y: 4)
                        // filamento
                        Capsule().fill(Brass.glow.opacity(glow * 0.35)).frame(width: 26, height: 44).blur(radius: 6).offset(y: 2)
                        Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.5), Brass.glow],
                                                      startPoint: .top, endPoint: .bottom).opacity(0.25 + glow * 0.75))
                            .frame(width: 4, height: 28).offset(y: 4)
                            .shadow(color: Brass.glow.opacity(glow), radius: 4)
                            .shadow(color: Brass.glow.opacity(glow * 0.8), radius: 10)
                        // getter prateado no topo
                        Ellipse().fill(Color(white: 0.75).opacity(0.5)).frame(width: 18, height: 6).offset(y: -24)
                        // reflexo
                        Capsule().fill(.white.opacity(0.35)).frame(width: 3, height: 34).offset(x: -9, y: -2)
                    }
                    .frame(width: 32, height: 62)
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: 15, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 15)
                        .stroke(.white.opacity(0.3), lineWidth: 0.8))
                    // base de baquelite
                    RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.05)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 36, height: 12)
                }
            }
            .frame(width: 40, height: 76)
        }
    }
}

// MARK: - VU meter

struct VUMeter: View {
    let label: String
    let rate: Double
    let powered: Bool
    @State private var smoothed: Double = 0

    private var level: Double { powered ? min(1, log10(1 + rate) / log10(1 + 2000)) : 0 }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // moldura de latão
                RoundedRectangle(cornerRadius: 7).fill(Brass.metal)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Brass.ink.opacity(0.6), lineWidth: 1))
                // mostrador iluminado
                RoundedRectangle(cornerRadius: 4)
                    .fill(RadialGradient(colors: [Brass.cream, Color(red: 0.93, green: 0.80, blue: 0.55)],
                                         center: .bottom, startRadius: 5, endRadius: 120))
                    .overlay(RoundedRectangle(cornerRadius: 4).fill(Brass.glow.opacity(powered ? 0.12 : 0)))
                    .padding(5)
                GeometryReader { g in
                    let pivot = CGPoint(x: g.size.width / 2, y: g.size.height - 8)
                    let radius = g.size.height * 0.72
                    // escala
                    Canvas { ctx, _ in
                        for i in 0...20 {
                            let f = Double(i) / 20
                            let a = Angle.degrees(-140 + f * 100).radians
                            let r1 = radius * (i % 5 == 0 ? 0.80 : 0.86), r2 = radius * 0.94
                            var p = Path()
                            p.move(to: CGPoint(x: pivot.x + cos(a) * r1, y: pivot.y + sin(a) * r1))
                            p.addLine(to: CGPoint(x: pivot.x + cos(a) * r2, y: pivot.y + sin(a) * r2))
                            ctx.stroke(p, with: .color(f > 0.75 ? .red : Brass.ink), lineWidth: i % 5 == 0 ? 1.4 : 0.7)
                        }
                        var arc = Path()
                        arc.addArc(center: pivot, radius: radius * 0.94, startAngle: .degrees(-140), endAngle: .degrees(-65), clockwise: false)
                        ctx.stroke(arc, with: .color(Brass.ink), lineWidth: 1)
                        var red = Path()
                        red.addArc(center: pivot, radius: radius * 0.94, startAngle: .degrees(-65), endAngle: .degrees(-40), clockwise: false)
                        ctx.stroke(red, with: .color(.red), lineWidth: 2.2)
                    }
                    Text("VU").font(.engraved(11)).foregroundStyle(Brass.ink.opacity(0.8))
                        .position(x: pivot.x, y: pivot.y - radius * 0.42)
                    // ponteiro
                    Capsule().fill(Color(red: 0.15, green: 0.08, blue: 0.04))
                        .frame(width: 1.6, height: radius * 0.95)
                        .offset(y: -radius * 0.95 / 2)
                        .rotationEffect(.degrees(-40 + smoothed * 80), anchor: .center)
                        .position(pivot)
                    Circle().fill(Brass.metal).frame(width: 9, height: 9).position(pivot)
                }
                .padding(5)
                .clipShape(RoundedRectangle(cornerRadius: 4).inset(by: 5))
                // vidro
                RoundedRectangle(cornerRadius: 4).inset(by: 5)
                    .fill(LinearGradient(colors: [.white.opacity(0.25), .clear, .clear], startPoint: .topLeading, endPoint: .center))
            }
            .frame(width: 150, height: 92)
            Engraved(label, size: 8.5)
        }
        .onChange(of: level, initial: true) { _, new in
            withAnimation(.interpolatingSpring(stiffness: 90, damping: 9)) { smoothed = new }
        }
    }
}

// MARK: - Controles

struct PilotLamp: View {
    let color: Color
    let lit: Bool
    var blinking = false
    var body: some View {
        if blinking {
            TimelineView(.periodic(from: .now, by: 0.6)) { ctx in
                let on = Int(ctx.date.timeIntervalSinceReferenceDate / 0.6) % 2 == 0
                PilotLamp(color: color, lit: lit && on)
            }
        } else {
            lamp
        }
    }

    private var lamp: some View {
        ZStack {
            Circle().fill(Brass.metal).frame(width: 18, height: 18)
            Circle()
                .fill(RadialGradient(colors: [lit ? .white.opacity(0.9) : .white.opacity(0.2), lit ? color : color.opacity(0.25), (lit ? color : .black).opacity(0.7)],
                                     center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: 7))
                .frame(width: 12, height: 12)
                .shadow(color: lit ? color : .clear, radius: 6)
        }
    }
}

struct NamePlate: View {
    let text: String
    var dim = false
    init(_ text: String, dim: Bool = false) { self.text = text; self.dim = dim }
    var body: some View {
        Text(text).font(.typewriter(11.5)).lineLimit(1)
            .foregroundStyle(Brass.cream.opacity(dim ? 0.55 : 1))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.12, green: 0.07, blue: 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Brass.mid, lineWidth: 1.2))
    }
}

/// Chave de alavanca ("bat handle") vintage.
struct ToggleLever: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        VStack(spacing: 4) {
            Text("ON").font(.engraved(7)).foregroundStyle(Brass.ink.opacity(isOn ? 0.9 : 0.4))
            ZStack {
                Circle().fill(RadialGradient(colors: [Brass.light, Brass.dark], center: .center, startRadius: 2, endRadius: 15))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(Brass.ink.opacity(0.6), lineWidth: 1))
                Circle().fill(Color(white: 0.15)).frame(width: 10, height: 10)
                // alavanca
                Capsule()
                    .fill(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.55), Color(white: 0.8)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 7, height: 24)
                    .overlay(Capsule().stroke(.black.opacity(0.4), lineWidth: 0.5))
                    .offset(y: isOn ? -11 : 11)
                    .shadow(color: .black.opacity(0.5), radius: 1.5, y: isOn ? 2 : -1)
            }
            .frame(height: 50)
            Text("OFF").font(.engraved(7)).foregroundStyle(Brass.ink.opacity(isOn ? 0.4 : 0.9))
            Text(title).font(.engraved(7.5)).multilineTextAlignment(.center).foregroundStyle(Brass.ink.opacity(0.85))
                .fixedSize()
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) { isOn.toggle() } }
        .help(title.replacingOccurrences(of: "\n", with: " "))
    }
}

/// Interruptor geral: alavanca grande com lâmpada.
struct MasterSwitch: View {
    let t: Strings
    @Binding var isOn: Bool
    var body: some View {
        VStack(spacing: 3) {
            PilotLamp(color: .red, lit: isOn)
            ToggleLeverMini(isOn: $isOn).help(isOn ? t.powerOff : t.powerOn)
            Engraved(t.power, size: 7)
        }
    }
}

struct ToggleLeverMini: View {
    @Binding var isOn: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.12)).frame(width: 22, height: 34)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brass.mid, lineWidth: 1.5))
            Capsule().fill(LinearGradient(colors: [Brass.light, Brass.dark], startPoint: .leading, endPoint: .trailing))
                .frame(width: 12, height: 16).offset(y: isOn ? -7 : 7)
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) { isOn.toggle() } }
    }
}

struct NixieCounter: View {
    let value: Int
    let digits: Int
    let powered: Bool
    var body: some View {
        let s = String(String(value % Int(pow(10, Double(digits)))).leftPad(to: digits))
        HStack(spacing: 2) {
            ForEach(Array(s.enumerated()), id: \.offset) { _, ch in
                ZStack {
                    UnevenRoundedRectangle(topLeadingRadius: 7, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 7)
                        .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.05)], startPoint: .top, endPoint: .bottom))
                    Text(String(ch)).font(.system(size: 15, weight: .light, design: .monospaced))
                        .foregroundStyle(powered ? Color(red: 1, green: 0.6, blue: 0.25) : Color(white: 0.3))
                        .shadow(color: powered ? Brass.glow : .clear, radius: 4)
                    UnevenRoundedRectangle(topLeadingRadius: 7, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 7)
                        .stroke(.white.opacity(0.2), lineWidth: 0.6)
                }
                .frame(width: 14, height: 24)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 4).fill(Brass.metal))
    }
}

/// Seletor de idioma: três teclas de latão com lâmpada no idioma ativo.
struct LanguageSelector: View {
    let title: String
    @Binding var lang: String
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                ForEach(Lang.allCases) { l in
                    let on = lang == l.rawValue
                    Text(l.rawValue.uppercased()).font(.engraved(9))
                        .foregroundStyle(on ? Brass.cream : Brass.ink.opacity(0.8))
                        .frame(width: 26, height: 18)
                        .background(RoundedRectangle(cornerRadius: 3).fill(on ? AnyShapeStyle(Color(red: 0.12, green: 0.07, blue: 0.04)) : AnyShapeStyle(Brass.metal)))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Brass.ink.opacity(0.6), lineWidth: 0.8))
                        .shadow(color: on ? Brass.glow.opacity(0.6) : .black.opacity(0.3), radius: on ? 3 : 1, y: on ? 0 : 1)
                        .contentShape(Rectangle())
                        .onTapGesture { lang = l.rawValue }
                }
            }
            Engraved(title, size: 7)
        }
    }
}

private extension String {
    func leftPad(to n: Int) -> String { count >= n ? self : String(repeating: "0", count: n - count) + self }
}

struct BrassButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var pressed = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 11, weight: .bold))
                Text(title).font(.engraved(9.5)).tracking(0.6).fixedSize()
            }
            .foregroundStyle(Brass.ink)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Capsule().fill(Brass.metal))
            .overlay(Capsule().stroke(Brass.ink.opacity(0.7), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1).brightness(configuration.isPressed ? -0.08 : 0)
    }
}
