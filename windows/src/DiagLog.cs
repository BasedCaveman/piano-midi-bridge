// Log de diagnóstico em %LOCALAPPDATA%\PianoMidiBridge\PianoMidiBridge.log (suporte e testes).
namespace PianoMidiBridge;

public static class DiagLog
{
    public static readonly string Folder = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PianoMidiBridge");
    public static readonly string FilePath = Path.Combine(Folder, "PianoMidiBridge.log");
    private static readonly object Gate = new();

    public static void Write(string message)
    {
        try
        {
            lock (Gate)
            {
                Directory.CreateDirectory(Folder);
                var info = new FileInfo(FilePath);
                if (info.Exists && info.Length > 1_000_000) info.Delete(); // mantém pequeno
                File.AppendAllText(FilePath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}  {message}{Environment.NewLine}");
            }
        }
        catch { /* log nunca derruba o app */ }
    }
}
