// Periférico Bluetooth LE MIDI: publica o serviço BLE MIDI padrão pelo servidor GATT
// do Windows (GattServiceProvider) e converte entre BLE MIDI e bytes MIDI comuns.
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Storage.Streams;

namespace PianoMidiBridge.Engine;

public enum BleStatus { Starting, Off, Unsupported, Idle, Advertising, Connected, Error }

public sealed class BleMidiPeripheral : IDisposable
{
    public static readonly Guid ServiceUuid = Guid.Parse("03B80E5A-EDE8-4B33-A751-6CE34EC4C700");
    public static readonly Guid CharacteristicUuid = Guid.Parse("7772E5DB-3868-4112-A1A9-F2669D106BF3");

    /// Bytes MIDI vindos do iPhone/iPad.
    public event Action<byte[]>? MidiReceived;
    /// Mudança de estado (disparada fora da thread de UI).
    public event Action<BleStatus, int>? StatusChanged;

    public BleStatus Status { get; private set; } = BleStatus.Starting;
    public int ConnectedCount { get; private set; }
    public string? LastError { get; private set; }

    private GattServiceProvider? _provider;
    private GattLocalCharacteristic? _characteristic;
    private readonly BleMidiEncoder _encoder = new();
    private readonly BleMidiDecoder _decoder = new();
    private readonly SemaphoreSlim _sendLock = new(1, 1);
    private bool _wantAdvertising;

    public async Task StartAsync()
    {
        _wantAdvertising = true;
        try
        {
            var adapter = await BluetoothAdapter.GetDefaultAsync();
            if (adapter == null) { Set(BleStatus.Off); return; }
            if (!adapter.IsLowEnergySupported || !adapter.IsPeripheralRoleSupported)
            {
                DiagLog.Write("BLE: adaptador sem suporte ao papel de periférico");
                Set(BleStatus.Unsupported); return;
            }
            var radio = await adapter.GetRadioAsync();
            if (radio != null && radio.State != Windows.Devices.Radios.RadioState.On)
            {
                Set(BleStatus.Off);
                radio.StateChanged += async (r, _) =>
                {
                    if (r.State == Windows.Devices.Radios.RadioState.On && _wantAdvertising && _provider == null)
                        await StartAsync();
                    else if (r.State != Windows.Devices.Radios.RadioState.On) Set(BleStatus.Off);
                };
                return;
            }

            if (_provider == null)
            {
                var result = await GattServiceProvider.CreateAsync(ServiceUuid);
                if (result.Error != BluetoothError.Success)
                {
                    Fail($"não foi possível criar o serviço ({result.Error})"); return;
                }
                _provider = result.ServiceProvider;

                var parameters = new GattLocalCharacteristicParameters
                {
                    CharacteristicProperties = GattCharacteristicProperties.Read
                        | GattCharacteristicProperties.WriteWithoutResponse
                        | GattCharacteristicProperties.Notify,
                    ReadProtectionLevel = GattProtectionLevel.Plain,
                    WriteProtectionLevel = GattProtectionLevel.Plain,
                    UserDescription = "MIDI I/O",
                };
                var ch = await _provider.Service.CreateCharacteristicAsync(CharacteristicUuid, parameters);
                if (ch.Error != BluetoothError.Success)
                {
                    Fail($"não foi possível criar a característica ({ch.Error})"); return;
                }
                _characteristic = ch.Characteristic;
                _characteristic.ReadRequested += OnReadRequested;
                _characteristic.WriteRequested += OnWriteRequested;
                _characteristic.SubscribedClientsChanged += OnSubscribedClientsChanged;
                _provider.AdvertisementStatusChanged += (p, e) =>
                {
                    DiagLog.Write($"BLE: anúncio {e.Status} ({e.Error})");
                    UpdateStatus();
                };
            }

            _provider.StartAdvertising(new GattServiceProviderAdvertisingParameters
            {
                IsConnectable = true,
                IsDiscoverable = true,
            });
            DiagLog.Write("BLE: anunciando serviço Bluetooth MIDI");
            UpdateStatus();
        }
        catch (Exception ex)
        {
            Fail(ex.Message);
        }
    }

    public void Stop()
    {
        _wantAdvertising = false;
        try { _provider?.StopAdvertising(); } catch { /* já parado */ }
        _encoder.Reset();
        _decoder.Reset();
        Set(BleStatus.Idle);
    }

    /// Envia bytes MIDI (mensagens completas ou trechos de SysEx) aos dispositivos conectados.
    public async Task SendAsync(byte[] bytes)
    {
        var ch = _characteristic;
        if (ch == null || ch.SubscribedClients.Count == 0 || bytes.Length == 0) return;
        await _sendLock.WaitAsync();
        try
        {
            int mtu = ch.SubscribedClients.Min(c => (int)c.MaxNotificationSize);
            mtu = Math.Clamp(mtu, 20, 512);
            foreach (var packet in _encoder.Packets(bytes, mtu))
                await ch.NotifyValueAsync(packet.AsBuffer());
        }
        catch (Exception ex)
        {
            DiagLog.Write($"BLE: falha ao enviar: {ex.Message}");
        }
        finally
        {
            _sendLock.Release();
        }
    }

    private async void OnReadRequested(GattLocalCharacteristic sender, GattReadRequestedEventArgs args)
    {
        using var deferral = args.GetDeferral();
        var request = await args.GetRequestAsync();
        // A especificação BLE MIDI pede leitura vazia.
        request?.RespondWithValue(new Windows.Storage.Streams.Buffer(0));
    }

    private async void OnWriteRequested(GattLocalCharacteristic sender, GattWriteRequestedEventArgs args)
    {
        using var deferral = args.GetDeferral();
        var request = await args.GetRequestAsync();
        if (request == null) return;
        var data = new byte[request.Value.Length];
        DataReader.FromBuffer(request.Value).ReadBytes(data);
        if (request.Option == GattWriteOption.WriteWithResponse) request.Respond();

        var midi = _decoder.Decode(data);
        if (midi.Length == 0) return;
        if (midi[0] == 0xF0)
            DiagLog.Write("iPhone → piano SysEx: " + string.Join(" ", midi.Take(16).Select(x => x.ToString("X2"))));
        MidiReceived?.Invoke(midi);
    }

    private void OnSubscribedClientsChanged(GattLocalCharacteristic sender, object args)
    {
        int n = sender.SubscribedClients.Count;
        DiagLog.Write(n > ConnectedCount ? $"BLE: dispositivo conectado (total {n})" : $"BLE: dispositivo desconectado (total {n})");
        if (n == 0) { _encoder.Reset(); _decoder.Reset(); }
        ConnectedCount = n;
        UpdateStatus();
    }

    private void UpdateStatus()
    {
        if (!_wantAdvertising) { Set(BleStatus.Idle); return; }
        if (ConnectedCount > 0) { Set(BleStatus.Connected); return; }
        var adv = _provider?.AdvertisementStatus;
        Set(adv is GattServiceProviderAdvertisementStatus.Started or GattServiceProviderAdvertisementStatus.StartedWithoutAllAdvertisementData
            ? BleStatus.Advertising
            : adv == GattServiceProviderAdvertisementStatus.Aborted ? BleStatus.Error : BleStatus.Starting);
    }

    private void Fail(string message)
    {
        LastError = message;
        DiagLog.Write("BLE: erro: " + message);
        Set(BleStatus.Error);
    }

    private void Set(BleStatus status)
    {
        if (status == Status && status != BleStatus.Connected) return;
        Status = status;
        if (status != BleStatus.Error) LastError = null;
        DiagLog.Write($"BLE: {status}");
        StatusChanged?.Invoke(status, ConnectedCount);
    }

    public void Dispose()
    {
        Stop();
        _sendLock.Dispose();
    }
}
