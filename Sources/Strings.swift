// Textos da interface em português, inglês e espanhol.
import Foundation

enum Lang: String, CaseIterable, Identifiable {
    case pt, en, es
    var id: String { rawValue }

    /// Idioma salvo pelo usuário; senão, o idioma do sistema; senão, inglês.
    static var current: Lang {
        if let saved = UserDefaults.standard.string(forKey: "lang"), let l = Lang(rawValue: saved) { return l }
        let sys = Locale.preferredLanguages.first?.prefix(2) ?? "en"
        return Lang(rawValue: String(sys)) ?? .en
    }
}

struct Strings {
    let subtitle: String
    let toPhone: String
    let toPiano: String
    let tubes: String
    let instrument: String
    let receiver: String
    let connectUSB: String
    let select: String
    let waitingPhone: String
    let filterClock: String
    let filterSensing: String
    let launchAtLogin: String
    let bytesFiltered: String
    let quit: String
    let power: String
    let powerOn: String
    let powerOff: String
    let language: String
    let windowHint: String
    let coreMIDIError: String
    let transmitter: String
    let phoneConnected: String
    let btOff: String
    let btUnauthorized: String
    let btUnsupported: String
    let openSettings: String
    /// Instrução mostrada enquanto espera o iPhone. %@ = nome anunciado.
    let connectHint: String
    let editNameHelp: String
    /// Dica para quando o iPhone não encontra o Mac.
    let notFoundHint: String

    static func of(_ lang: Lang) -> Strings {
        switch lang {
        case .pt: return pt
        case .en: return en
        case .es: return es
        }
    }

    static let pt = Strings(
        subtitle: "Transmissor Bluetooth de Mensagens Musicais · Mod. 1",
        toPhone: "PIANO ➜ iPHONE", toPiano: "iPHONE ➜ PIANO", tubes: "VÁLVULAS",
        instrument: "INSTRUMENTO", receiver: "RECEPTOR",
        connectUSB: "— conecte o cabo USB —", select: "selecionar", waitingPhone: "— aguardando iPhone —",
        filterClock: "FILTRO\nCLOCK F8", filterSensing: "FILTRO\nSENSING FE", launchAtLogin: "LIGAR COM\nO MAC",
        bytesFiltered: "BYTES FILTRADOS",
        quit: "DESLIGAR",
        power: "FORÇA", powerOn: "Ligar a ponte", powerOff: "Desligar a ponte",
        language: "IDIOMA",
        windowHint: "Pode fechar esta janela: a ponte segue ativa no ícone 🎹 da barra de menus. Para reabrir, abra o app de novo.",
        coreMIDIError: "Falha ao iniciar o CoreMIDI",
        transmitter: "TRANSMISSOR", phoneConnected: "iPhone/iPad conectado",
        btOff: "Bluetooth do Mac desligado", btUnauthorized: "Bluetooth não permitido", btUnsupported: "Este Mac não suporta Bluetooth LE",
        openSettings: "ABRIR AJUSTES",
        connectHint: "No iPhone: Smart Pianist ▸ ícone de conexão ▸ Assistente ▸ Bluetooth ▸ Connect Bluetooth MIDI Device ▸ “%@” (ou o nome antigo do seu Mac)",
        editNameHelp: "Nome que o iPhone vê. Clique para editar.",
        notFoundHint: "Não aparece? No iPhone, ligue a chave em Ajustes ▸ Bluetooth: desligar pela Central de Controle bloqueia aparelhos novos.")

    static let en = Strings(
        subtitle: "Bluetooth Musical Message Transmitter · Mod. 1",
        toPhone: "PIANO ➜ iPHONE", toPiano: "iPHONE ➜ PIANO", tubes: "VALVES",
        instrument: "INSTRUMENT", receiver: "RECEIVER",
        connectUSB: "— connect the USB cable —", select: "select", waitingPhone: "— waiting for iPhone —",
        filterClock: "FILTER\nCLOCK F8", filterSensing: "FILTER\nSENSING FE", launchAtLogin: "START WITH\nTHE MAC",
        bytesFiltered: "BYTES FILTERED",
        quit: "SHUT DOWN",
        power: "POWER", powerOn: "Turn the bridge on", powerOff: "Turn the bridge off",
        language: "LANGUAGE",
        windowHint: "You can close this window: the bridge keeps running from the 🎹 icon in the menu bar. To reopen, launch the app again.",
        coreMIDIError: "Could not start CoreMIDI",
        transmitter: "TRANSMITTER", phoneConnected: "iPhone/iPad connected",
        btOff: "Mac Bluetooth is off", btUnauthorized: "Bluetooth not allowed", btUnsupported: "This Mac doesn't support Bluetooth LE",
        openSettings: "OPEN SETTINGS",
        connectHint: "On the iPhone: Smart Pianist ▸ connection icon ▸ Wizard ▸ Bluetooth ▸ Connect Bluetooth MIDI Device ▸ “%@” (or your Mac's previous name)",
        editNameHelp: "Name the iPhone sees. Click to edit.",
        notFoundHint: "Not showing up? On the iPhone, turn on the switch in Settings ▸ Bluetooth: turning it off from Control Center blocks new devices.")

    static let es = Strings(
        subtitle: "Transmisor Bluetooth de Mensajes Musicales · Mod. 1",
        toPhone: "PIANO ➜ iPHONE", toPiano: "iPHONE ➜ PIANO", tubes: "VÁLVULAS",
        instrument: "INSTRUMENTO", receiver: "RECEPTOR",
        connectUSB: "— conecte el cable USB —", select: "seleccionar", waitingPhone: "— esperando el iPhone —",
        filterClock: "FILTRO\nCLOCK F8", filterSensing: "FILTRO\nSENSING FE", launchAtLogin: "INICIAR CON\nEL MAC",
        bytesFiltered: "BYTES FILTRADOS",
        quit: "APAGAR",
        power: "ENERGÍA", powerOn: "Encender el puente", powerOff: "Apagar el puente",
        language: "IDIOMA",
        windowHint: "Puede cerrar esta ventana: el puente sigue activo en el icono 🎹 de la barra de menús. Para reabrirla, abra la app de nuevo.",
        coreMIDIError: "No se pudo iniciar CoreMIDI",
        transmitter: "TRANSMISOR", phoneConnected: "iPhone/iPad conectado",
        btOff: "Bluetooth del Mac apagado", btUnauthorized: "Bluetooth no permitido", btUnsupported: "Este Mac no admite Bluetooth LE",
        openSettings: "ABRIR AJUSTES",
        connectHint: "En el iPhone: Smart Pianist ▸ icono de conexión ▸ Asistente ▸ Bluetooth ▸ Connect Bluetooth MIDI Device ▸ “%@” (o el nombre anterior de su Mac)",
        editNameHelp: "Nombre que ve el iPhone. Haga clic para editar.",
        notFoundHint: "¿No aparece? En el iPhone, active el interruptor en Ajustes ▸ Bluetooth: apagarlo desde el Centro de control bloquea dispositivos nuevos.")
}
