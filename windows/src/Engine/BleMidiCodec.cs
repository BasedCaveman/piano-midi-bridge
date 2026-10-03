// Formato Bluetooth LE MIDI (especificação MMA/AMEI "MIDI over Bluetooth LE"):
// cada pacote começa com um cabeçalho e cada mensagem é precedida por um timestamp.
// Porte direto do codec da versão macOS (Sources/BLEMIDIPeripheral.swift).
namespace PianoMidiBridge.Engine;

internal static class BleTimestamp
{
    /// Timestamp de 13 bits em milissegundos: (cabeçalho, byte de timestamp).
    public static (byte Header, byte Ts) Now()
    {
        var ms = (uint)(Environment.TickCount64 & 0x1FFF);
        return ((byte)(0x80 | ((ms >> 7) & 0x3F)), (byte)(0x80 | (ms & 0x7F)));
    }
}

/// Converte bytes MIDI em pacotes BLE MIDI. Guarda estado entre chamadas porque
/// um SysEx do piano pode chegar em vários pedaços.
internal sealed class BleMidiEncoder
{
    private bool _inSysex;

    public void Reset() => _inSysex = false;

    public List<byte[]> Packets(ReadOnlySpan<byte> bytes, int maxLength)
    {
        var (header, ts) = BleTimestamp.Now();
        var output = new List<byte[]>();
        var cur = new List<byte>(maxLength) { header };

        void NewPacket()
        {
            output.Add(cur.ToArray());
            cur.Clear();
            cur.Add(header);
        }

        int i = 0;
        while (i < bytes.Length)
        {
            byte b = bytes[i];
            if (b >= 0x80)
            {
                if (b >= 0xF8)
                {
                    // tempo real: pode aparecer até no meio de um SysEx
                    if (cur.Count + 2 > maxLength) NewPacket();
                    cur.Add(ts); cur.Add(b); i++; continue;
                }
                if (b == 0xF7)
                {
                    if (cur.Count + 2 > maxLength) NewPacket();
                    cur.Add(ts); cur.Add(b); _inSysex = false; i++; continue;
                }
                if (b == 0xF0)
                {
                    if (cur.Count + 3 > maxLength) NewPacket();
                    cur.Add(ts); cur.Add(b); _inSysex = true; i++; continue;
                }
                // mensagem de canal / sistema comum: mantém inteira no mesmo pacote
                int len = 1;
                while (i + len < bytes.Length && bytes[i + len] < 0x80) len++;
                if (cur.Count + 1 + len > maxLength) NewPacket();
                cur.Add(ts);
                for (int k = 0; k < len; k++) cur.Add(bytes[i + k]);
                i += len;
                _inSysex = false;
            }
            else
            {
                // byte de dados: dentro de SysEx pode quebrar em qualquer ponto
                if (cur.Count + 1 > maxLength) NewPacket();
                if (!_inSysex && cur.Count == 1) cur.Add(ts);
                cur.Add(b); i++;
            }
        }
        if (cur.Count > 1) output.Add(cur.ToArray());
        return output;
    }
}

/// Converte pacotes BLE MIDI em bytes MIDI comuns (reinsere running status).
internal sealed class BleMidiDecoder
{
    private bool _inSysex;
    private byte _runningStatus;

    public void Reset() { _inSysex = false; _runningStatus = 0; }

    public byte[] Decode(ReadOnlySpan<byte> packet)
    {
        if (packet.Length < 2 || (packet[0] & 0x80) == 0) return Array.Empty<byte>();
        var output = new List<byte>(packet.Length);
        bool expectStatus = false;
        for (int i = 1; i < packet.Length; i++)
        {
            byte b = packet[i];
            if ((b & 0x80) != 0)
            {
                if (!expectStatus)
                {
                    expectStatus = true; // é um timestamp
                }
                else
                {
                    output.Add(b);       // é um status
                    expectStatus = false;
                    if (b == 0xF0) _inSysex = true;
                    else if (b == 0xF7) _inSysex = false;
                    else if (b < 0xF0) _runningStatus = b;
                    else if (b < 0xF8) _runningStatus = 0;
                }
            }
            else
            {
                if (expectStatus && !_inSysex && _runningStatus != 0)
                    output.Add(_runningStatus); // running status depois de timestamp
                expectStatus = false;
                output.Add(b);
            }
        }
        return output.ToArray();
    }
}
