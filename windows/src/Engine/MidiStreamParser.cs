// Monta mensagens MIDI completas a partir de um fluxo de bytes (com running status
// e SysEx fragmentado), porque o Windows envia uma mensagem por chamada.
namespace PianoMidiBridge.Engine;

internal sealed class MidiStreamParser
{
    private readonly List<byte> _sysex = new();
    private bool _inSysex;
    private byte _running;
    private readonly List<byte> _msg = new(3);
    private int _needed;

    private static int DataLength(byte status) => status switch
    {
        >= 0x80 and < 0xC0 => 2,
        >= 0xC0 and < 0xE0 => 1,
        >= 0xE0 and < 0xF0 => 2,
        0xF1 or 0xF3 => 1,
        0xF2 => 2,
        _ => 0,
    };

    public IEnumerable<byte[]> Feed(ReadOnlyMemory<byte> data)
    {
        var result = new List<byte[]>();
        foreach (var b in data.Span)
        {
            if (b >= 0xF8) { result.Add(new[] { b }); continue; } // tempo real
            if (b == 0xF0) { _inSysex = true; _sysex.Clear(); _sysex.Add(b); _running = 0; continue; }
            if (b == 0xF7)
            {
                if (_inSysex) { _sysex.Add(b); result.Add(_sysex.ToArray()); }
                _inSysex = false; _sysex.Clear(); continue;
            }
            if (_inSysex)
            {
                if (b < 0x80) { _sysex.Add(b); continue; }
                _inSysex = false; _sysex.Clear(); // SysEx interrompido: descarta
            }
            if (b >= 0x80)
            {
                _msg.Clear(); _msg.Add(b);
                _needed = DataLength(b);
                _running = b < 0xF0 ? b : (byte)0;
                if (_needed == 0) { result.Add(_msg.ToArray()); _msg.Clear(); }
                continue;
            }
            // byte de dados
            if (_msg.Count == 0)
            {
                if (_running == 0) continue; // dado solto sem status
                _msg.Add(_running); _needed = DataLength(_running);
            }
            _msg.Add(b);
            if (_msg.Count == _needed + 1) { result.Add(_msg.ToArray()); _msg.Clear(); }
        }
        return result;
    }
}
