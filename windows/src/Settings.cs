// Preferências do usuário em %APPDATA%\PianoMidiBridge\settings.json.
using System.Text.Json;

namespace PianoMidiBridge;

public sealed class Settings
{
    public string? Language { get; set; }
    public bool FilterClock { get; set; } = true;
    public bool FilterActiveSensing { get; set; } = true;
    public string? PianoName { get; set; }
    public bool BridgeOn { get; set; } = true;

    private static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "PianoMidiBridge", "settings.json");

    public static Settings Load()
    {
        try
        {
            if (File.Exists(FilePath))
                return JsonSerializer.Deserialize<Settings>(File.ReadAllText(FilePath)) ?? new Settings();
        }
        catch (Exception ex) { DiagLog.Write("Configurações ilegíveis, usando padrão: " + ex.Message); }
        return new Settings();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception ex) { DiagLog.Write("Falha ao salvar configurações: " + ex.Message); }
    }
}
