// Textos da interface em português, inglês e espanhol (mesmos da versão macOS).
using System.Globalization;

namespace PianoMidiBridge;

public enum Lang { Pt, En, Es }

public sealed record Strings(
    string Subtitle, string ToPhone, string ToPiano, string Tubes,
    string Instrument, string Transmitter, string Receiver,
    string ConnectUsb, string Select, string WaitingPhone, string PhoneConnected,
    string FilterClock, string FilterSensing, string LaunchAtLogin, string BytesFiltered,
    string Quit, string Power, string PowerOn, string PowerOff, string Language,
    string WindowHint, string BtOff, string BtUnsupported, string BtError, string OpenSettings,
    string TransmitterName, string ConnectHint, string NotFoundHint,
    string TrayOpen, string TrayQuit, string TrayRunning)
{
    public static Lang SystemDefault()
    {
        var two = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;
        return two switch { "pt" => Lang.Pt, "es" => Lang.Es, _ => Lang.En };
    }

    public static Strings Of(Lang lang) => lang switch { Lang.Pt => Pt, Lang.Es => Es, _ => En };

    public static readonly Strings Pt = new(
        "Transmissor Bluetooth de Mensagens Musicais · Mod. 1", "PIANO ➜ iPHONE", "iPHONE ➜ PIANO", "VÁLVULAS",
        "INSTRUMENTO", "TRANSMISSOR", "RECEPTOR",
        "— conecte o cabo USB —", "selecionar", "— aguardando iPhone —", "iPhone/iPad conectado",
        "FILTRO\nCLOCK F8", "FILTRO\nSENSING FE", "LIGAR COM\nO WINDOWS", "BYTES FILTRADOS",
        "DESLIGAR", "FORÇA", "Ligar a ponte", "Desligar a ponte", "IDIOMA",
        "Pode fechar esta janela: a ponte segue ativa no ícone 🎹 da bandeja (perto do relógio).",
        "Bluetooth do PC desligado", "Este PC não suporta Bluetooth LE como periférico", "Erro no Bluetooth (veja o log)", "ABRIR AJUSTES",
        "nome Bluetooth deste PC",
        "No iPhone: Smart Pianist ▸ ícone de conexão ▸ Assistente ▸ Bluetooth ▸ Connect Bluetooth MIDI Device ▸ “{0}”",
        "Não aparece? No iPhone, ligue a chave em Ajustes ▸ Bluetooth: desligar pela Central de Controle bloqueia aparelhos novos.",
        "Abrir painel", "Sair", "Piano MIDI Bridge está rodando na bandeja.");

    public static readonly Strings En = new(
        "Bluetooth Musical Message Transmitter · Mod. 1", "PIANO ➜ iPHONE", "iPHONE ➜ PIANO", "VALVES",
        "INSTRUMENT", "TRANSMITTER", "RECEIVER",
        "— connect the USB cable —", "select", "— waiting for iPhone —", "iPhone/iPad connected",
        "FILTER\nCLOCK F8", "FILTER\nSENSING FE", "START WITH\nWINDOWS", "BYTES FILTERED",
        "SHUT DOWN", "POWER", "Turn the bridge on", "Turn the bridge off", "LANGUAGE",
        "You can close this window: the bridge keeps running from the 🎹 icon in the system tray (near the clock).",
        "PC Bluetooth is off", "This PC doesn't support Bluetooth LE peripheral mode", "Bluetooth error (see the log)", "OPEN SETTINGS",
        "this PC's Bluetooth name",
        "On the iPhone: Smart Pianist ▸ connection icon ▸ Wizard ▸ Bluetooth ▸ Connect Bluetooth MIDI Device ▸ “{0}”",
        "Not showing up? On the iPhone, turn on the switch in Settings ▸ Bluetooth: turning it off from Control Center blocks new devices.",
        "Open panel", "Quit", "Piano MIDI Bridge is running in the system tray.");

    public static readonly Strings Es = new(
        "Transmisor Bluetooth de Mensajes Musicales · Mod. 1", "PIANO ➜ iPHONE", "iPHONE ➜ PIANO", "VÁLVULAS",
        "INSTRUMENTO", "TRANSMISOR", "RECEPTOR",
        "— conecte el cable USB —", "seleccionar", "— esperando el iPhone —", "iPhone/iPad conectado",
        "FILTRO\nCLOCK F8", "FILTRO\nSENSING FE", "INICIAR CON\nWINDOWS", "BYTES FILTRADOS",
        "APAGAR", "ENERGÍA", "Encender el puente", "Apagar el puente", "IDIOMA",
        "Puede cerrar esta ventana: el puente sigue activo en el icono 🎹 de la bandeja del sistema (junto al reloj).",
        "Bluetooth del PC apagado", "Este PC no admite Bluetooth LE como periférico", "Error de Bluetooth (vea el registro)", "ABRIR AJUSTES",
        "nombre Bluetooth de este PC",
        "En el iPhone: Smart Pianist ▸ icono de conexión ▸ Asistente ▸ Bluetooth ▸ Connect Bluetooth MIDI Device ▸ “{0}”",
        "¿No aparece? En el iPhone, active el interruptor en Ajustes ▸ Bluetooth: apagarlo desde el Centro de control bloquea dispositivos nuevos.",
        "Abrir panel", "Salir", "Piano MIDI Bridge está activo en la bandeja del sistema.");
}
