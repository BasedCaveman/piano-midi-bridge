// Ponte MIDI bidirecional: instrumento USB (Windows.Devices.Midi) ↔ iPhone/iPad
// pelo periférico Bluetooth LE MIDI embutido.
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Devices.Enumeration;
using Windows.Devices.Midi;

namespace PianoMidiBridge.Engine;

public sealed record MidiDevice(string Name, string InId, string? OutId);

public sealed class MidiBridge : INotifyPropertyChanged, IDisposable
{
    public event PropertyChangedEventHandler? PropertyChanged;

    private readonly SynchronizationContext _ui;
    private readonly Settings _settings;
    private readonly BleMidiPeripheral _ble = new();
    private readonly MidiStreamParser _toPianoParser = new();
    private readonly object _pianoGate = new();
    private MidiInPort? _pianoIn;
    private IMidiOutPort? _pianoOut;
    private DeviceWatcher? _inWatcher, _outWatcher;
    private readonly System.Threading.Timer _rateTimer;
    private long _toDevice, _toPiano, _filtered, _lastToDevice, _lastToPiano;

    public MidiBridge(Settings settings)
    {
        _ui = SynchronizationContext.Current ?? new SynchronizationContext();
        _settings = settings;
        _ble.MidiReceived += bytes => SendToPiano(bytes);
        _ble.StatusChanged += (s, n) => Post(() => { BleStatus = s; ConnectedCount = n; Notify(nameof(IsLinked)); });
        _rateTimer = new System.Threading.Timer(_ => UpdateRates(), null, 200, 200);
    }

    // MARK: Estado exposto à interface

    public IReadOnlyList<MidiDevice> Instruments { get; private set; } = Array.Empty<MidiDevice>();
    public MidiDevice? Piano { get; private set; }
    public bool IsRunning { get; private set; }
    public BleStatus BleStatus { get; private set; } = BleStatus.Starting;
    public int ConnectedCount { get; private set; }
    public bool IsLinked => BleStatus == BleStatus.Connected;
    public string? BleError => _ble.LastError;
    public long ToDevice { get; private set; }
    public long ToPiano { get; private set; }
    public long Filtered { get; private set; }
    public double RateToDevice { get; private set; }
    public double RateToPiano { get; private set; }

    public bool FilterClock
    {
        get => _settings.FilterClock;
        set { _settings.FilterClock = value; _settings.Save(); Notify(); }
    }
    public bool FilterActiveSensing
    {
        get => _settings.FilterActiveSensing;
        set { _settings.FilterActiveSensing = value; _settings.Save(); Notify(); }
    }

    // MARK: Ciclo de vida

    public async Task InitializeAsync()
    {
        DiagLog.Write($"App iniciado — versão {typeof(MidiBridge).Assembly.GetName().Version}, {Environment.OSVersion}");
        _inWatcher = DeviceInformation.CreateWatcher(MidiInPort.GetDeviceSelector());
        _outWatcher = DeviceInformation.CreateWatcher(MidiOutPort.GetDeviceSelector());
        foreach (var w in new[] { _inWatcher, _outWatcher })
        {
            w.Added += (_, _) => ScheduleRefresh();
            w.Removed += (_, _) => ScheduleRefresh();
            w.Start();
        }
        await RefreshAsync();
        if (_settings.BridgeOn) await StartAsync();
    }

    public async Task StartAsync()
    {
        IsRunning = true; _settings.BridgeOn = true; _settings.Save();
        DiagLog.Write($"Ponte ligada (piano: {Piano?.Name ?? "nenhum"})");
        Notify(nameof(IsRunning));
        await OpenPianoAsync();
        await _ble.StartAsync();
    }

    public void Stop()
    {
        IsRunning = false; _settings.BridgeOn = false; _settings.Save();
        DiagLog.Write("Ponte desligada");
        Notify(nameof(IsRunning));
        ClosePiano();
        _ble.Stop();
    }

    public async Task SelectPianoAsync(MidiDevice device)
    {
        Piano = device; _settings.PianoName = device.Name; _settings.Save();
        Notify(nameof(Piano));
        if (IsRunning) await OpenPianoAsync();
    }

    // MARK: Instrumentos USB

    private async Task RefreshAsync()
    {
        var ins = await DeviceInformation.FindAllAsync(MidiInPort.GetDeviceSelector());
        var outs = (await DeviceInformation.FindAllAsync(MidiOutPort.GetDeviceSelector()))
            .Where(o => !o.Name.Contains("GS Wavetable", StringComparison.OrdinalIgnoreCase)).ToList();

        // Casa entrada e saída do mesmo instrumento pelo nome.
        var list = ins.Select(i =>
        {
            var o = outs.FirstOrDefault(x => x.Name == i.Name)
                 ?? outs.FirstOrDefault(x => Similar(x.Name, i.Name));
            return new MidiDevice(i.Name, i.Id, o?.Id);
        }).ToList();

        var names = string.Join(", ", list.Select(d => d.Name + (d.OutId == null ? " (sem saída)" : "")));
        if (names != string.Join(", ", Instruments.Select(d => d.Name + (d.OutId == null ? " (sem saída)" : ""))))
            DiagLog.Write("MIDI: instrumentos = " + (names.Length > 0 ? names : "nenhum"));
        Instruments = list;
        Notify(nameof(Instruments));

        var keep = Piano != null ? list.FirstOrDefault(d => d.InId == Piano.InId) : null;
        var pick = keep
            ?? list.FirstOrDefault(d => d.Name == _settings.PianoName)
            ?? list.FirstOrDefault(d => d.Name.Contains("piano", StringComparison.OrdinalIgnoreCase))
            ?? list.FirstOrDefault();
        if (pick?.InId != Piano?.InId || (pick == null) != (Piano == null))
        {
            Piano = pick;
            Notify(nameof(Piano));
            if (IsRunning) await OpenPianoAsync();
        }
    }

    private int _refreshGeneration;

    /// O Windows dispara um evento por porta ao enumerar: agrupa numa única atualização.
    private void ScheduleRefresh()
    {
        int gen = Interlocked.Increment(ref _refreshGeneration);
        _ = Task.Delay(400).ContinueWith(_ =>
        {
            if (gen == Volatile.Read(ref _refreshGeneration)) Post(async () => await RefreshAsync());
        });
    }

    private static bool Similar(string a, string b)
    {
        static string Core(string s) => new string(s.Where(char.IsLetterOrDigit).ToArray()).ToLowerInvariant();
        var (x, y) = (Core(a), Core(b));
        return x.Length > 0 && y.Length > 0 && (x.Contains(y) || y.Contains(x));
    }

    private async Task OpenPianoAsync()
    {
        ClosePiano();
        var piano = Piano;
        if (piano == null) return;
        try
        {
            var input = await MidiInPort.FromIdAsync(piano.InId);
            var output = piano.OutId != null ? await MidiOutPort.FromIdAsync(piano.OutId) : null;
            if (input == null) DiagLog.Write($"MIDI: não abriu a entrada de {piano.Name} (outro app pode estar usando)");
            if (output == null) DiagLog.Write($"MIDI: não abriu a saída de {piano.Name}");
            lock (_pianoGate) { _pianoIn = input; _pianoOut = output; }
            if (input != null) input.MessageReceived += OnPianoMessage;
            DiagLog.Write($"MIDI: piano aberto ({piano.Name})");
        }
        catch (Exception ex)
        {
            DiagLog.Write($"MIDI: erro ao abrir {piano.Name}: {ex.Message}");
        }
    }

    private void ClosePiano()
    {
        lock (_pianoGate)
        {
            if (_pianoIn != null) { _pianoIn.MessageReceived -= OnPianoMessage; _pianoIn.Dispose(); }
            _pianoOut?.Dispose();
            _pianoIn = null; _pianoOut = null;
        }
    }

    // MARK: Encaminhamento

    private void OnPianoMessage(MidiInPort sender, MidiMessageReceivedEventArgs args)
    {
        var raw = args.Message.RawData.ToArray();
        if (raw.Length == 0) return;
        // Bytes de tempo real (F8 clock, FE active sensing): só removidos no sentido piano → iPhone.
        bool dropClock = _settings.FilterClock, dropSensing = _settings.FilterActiveSensing;
        var kept = raw.Where(b => !(b == 0xF8 && dropClock) && !(b == 0xFE && dropSensing)).ToArray();
        if (kept.Length < raw.Length) Interlocked.Add(ref _filtered, raw.Length - kept.Length);
        if (kept.Length == 0 || !IsRunning) return;
        if (_ble.ConnectedCount == 0) return;
        Interlocked.Add(ref _toDevice, kept.Length);
        _ = _ble.SendAsync(kept);
    }

    private void SendToPiano(byte[] bytes)
    {
        IMidiOutPort? output;
        lock (_pianoGate) output = _pianoOut;
        if (output == null || !IsRunning) return;
        foreach (var msg in _toPianoParser.Feed(bytes))
        {
            try { output.SendBuffer(msg.AsBuffer()); }
            catch (Exception ex) { DiagLog.Write("MIDI: falha ao enviar ao piano: " + ex.Message); }
        }
        Interlocked.Add(ref _toPiano, bytes.Length);
    }

    private void UpdateRates()
    {
        long dev = Interlocked.Read(ref _toDevice), pno = Interlocked.Read(ref _toPiano), flt = Interlocked.Read(ref _filtered);
        double rDev = (dev - _lastToDevice) / 0.2, rPno = (pno - _lastToPiano) / 0.2;
        _lastToDevice = dev; _lastToPiano = pno;
        Post(() =>
        {
            ToDevice = dev; ToPiano = pno; Filtered = flt; RateToDevice = rDev; RateToPiano = rPno;
            Notify(nameof(ToDevice)); Notify(nameof(ToPiano)); Notify(nameof(Filtered));
            Notify(nameof(RateToDevice)); Notify(nameof(RateToPiano));
        });
    }

    // MARK: Utilidades

    private void Post(Action action) => _ui.Post(_ => action(), null);
    private void Post(Func<Task> action) => _ui.Post(async _ => await action(), null);
    private void Notify([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    public void Dispose()
    {
        _rateTimer.Dispose();
        _inWatcher?.Stop(); _outWatcher?.Stop();
        ClosePiano();
        _ble.Dispose();
    }
}
