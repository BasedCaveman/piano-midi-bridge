// Testes simples (sem framework) do codec BLE MIDI e do parser de mensagens.
using PianoMidiBridge.Engine;

int failures = 0;
void Check(string name, bool ok) { Console.WriteLine($"{(ok ? "ok  " : "FAIL")}  {name}"); if (!ok) failures++; }
string Hex(IEnumerable<byte> b) => string.Join(" ", b.Select(x => x.ToString("X2")));

byte[] RoundTrip(byte[] midi, int mtu)
{
    var enc = new BleMidiEncoder(); var dec = new BleMidiDecoder();
    return enc.Packets(midi, mtu).SelectMany(p => dec.Decode(p)).ToArray();
}

// 1. Nota simples
var note = new byte[] { 0x90, 0x3C, 0x40 };
Check("note on ida e volta", RoundTrip(note, 20).SequenceEqual(note));

// 2. Várias mensagens num pacote
var multi = new byte[] { 0x90, 0x3C, 0x40, 0x80, 0x3C, 0x00, 0xB0, 0x40, 0x7F };
Check("várias mensagens", RoundTrip(multi, 20).SequenceEqual(multi));

// 3. SysEx de identificação (o primeiro que o Smart Pianist manda)
var ident = new byte[] { 0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7 };
Check("SysEx curto", RoundTrip(ident, 20).SequenceEqual(ident));

// 4. SysEx longo dividido em vários pacotes (MTU mínimo 20)
var longSysex = new[] { (byte)0xF0 }.Concat(Enumerable.Range(0, 300).Select(i => (byte)(i % 0x7F))).Append((byte)0xF7).ToArray();
var packets = new BleMidiEncoder().Packets(longSysex, 20);
Check($"SysEx longo em {packets.Count} pacotes ≤ 20 bytes", packets.All(p => p.Length <= 20) && packets.Count > 10);
Check("SysEx longo ida e volta", RoundTrip(longSysex, 20).SequenceEqual(longSysex));

// 5. SysEx do piano chegando em pedaços (encoder guarda estado)
var enc5 = new BleMidiEncoder(); var dec5 = new BleMidiDecoder();
var part1 = new byte[] { 0xF0, 0x43, 0x73, 0x01, 0x52 };
var part2 = new byte[] { 0x25, 0x26, 0x01, 0xF7 };
var out5 = enc5.Packets(part1, 20).Concat(enc5.Packets(part2, 20)).SelectMany(p => dec5.Decode(p)).ToArray();
Check("SysEx em pedaços", out5.SequenceEqual(part1.Concat(part2)));

// 6. Running status vindo do iPhone: [cab][ts]90 3C 40 [ts]3E 40 → reinsere 90
var dec6 = new BleMidiDecoder();
var rs = dec6.Decode(new byte[] { 0x80, 0x80, 0x90, 0x3C, 0x40, 0x81, 0x3E, 0x40 });
Check($"running status ({Hex(rs)})", rs.SequenceEqual(new byte[] { 0x90, 0x3C, 0x40, 0x90, 0x3E, 0x40 }));

// 7. Running status sem timestamp intermediário: [cab][ts]90 3C 40 3E 40
var rs2 = new BleMidiDecoder().Decode(new byte[] { 0x80, 0x80, 0x90, 0x3C, 0x40, 0x3E, 0x40 });
Check($"running status sem timestamp ({Hex(rs2)})", rs2.SequenceEqual(new byte[] { 0x90, 0x3C, 0x40, 0x3E, 0x40 }));

// 8. Parser: monta mensagens completas para o Windows
var parser = new MidiStreamParser();
var msgs = parser.Feed(new byte[] { 0x90, 0x3C, 0x40, 0x3E, 0x40, 0xF8, 0xC0, 0x05, 0xF0, 0x43, 0x10 }).ToList();
msgs.AddRange(parser.Feed(new byte[] { 0x4C, 0x00, 0xF7, 0xB0, 0x40, 0x7F }));
var expected = new[] { "90 3C 40", "90 3E 40", "F8", "C0 05", "F0 43 10 4C 00 F7", "B0 40 7F" };
Check("parser: " + string.Join(" | ", msgs.Select(Hex)), msgs.Select(Hex).SequenceEqual(expected));

// 9. Tempo real no meio de SysEx
var rt = new byte[] { 0xF0, 0x43, 0xF8, 0x10, 0xF7 };
Check("tempo real dentro de SysEx", RoundTrip(rt, 20).SequenceEqual(rt));

Console.WriteLine(failures == 0 ? "\nTodos os testes passaram." : $"\n{failures} teste(s) falharam.");
return failures == 0 ? 0 : 1;
