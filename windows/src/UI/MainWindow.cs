// Painel principal (mesmo layout da versão macOS), montado em código.
using System.ComponentModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Microsoft.Win32;
using PianoMidiBridge.Engine;

namespace PianoMidiBridge.UI;

public sealed class MainWindow : Window
{
    private readonly MidiBridge _bridge;
    private readonly Settings _settings;
    private Lang _lang;
    private Strings T => Strings.Of(_lang);

    // elementos que mudam com o estado / idioma
    private readonly TextBlock _subtitle = new() { FontFamily = Brass.Typewriter, FontSize = 10.5, Foreground = Brass.InkBrush(0.7), HorizontalAlignment = HorizontalAlignment.Center };
    private readonly Gear _gearA = new() { Width = 34, Height = 34, Teeth = 12, Speed = 1 };
    private readonly Gear _gearB = new() { Width = 26, Height = 26, Teeth = 9, Speed = -1.4 };
    private readonly PilotLamp _powerLamp = new() { Color = Colors.Red };
    private readonly ToggleLever _powerLever = new();
    private readonly TextBlock _powerLabel = Brass.EngravedText("", 7.5);
    private readonly VuMeter _vuOut = new(), _vuIn = new();
    private readonly TextBlock _vuOutLabel = Brass.EngravedText("", 8.5), _vuInLabel = Brass.EngravedText("", 8.5), _tubesLabel = Brass.EngravedText("", 8);
    private readonly VacuumTube _tubeA = new(), _tubeB = new();
    private readonly PilotLamp _instLamp = new(), _txLamp = new(), _rxLamp = new();
    private readonly TextBlock _instLabel = Brass.EngravedText("", 9), _txLabel = Brass.EngravedText("", 9), _rxLabel = Brass.EngravedText("", 9);
    private readonly NamePlate _instPlate = new(), _txPlate = new(), _rxPlate = new();
    private readonly BrassButton _openSettings = new("", "");
    private readonly TextBlock _hint = new() { FontFamily = Brass.Typewriter, FontSize = 11, Foreground = Brass.InkBrush(0.9), TextWrapping = TextWrapping.Wrap };
    private readonly TextBlock _notFound = new() { FontFamily = Brass.Typewriter, FontSize = 10, Foreground = Brass.InkBrush(0.65), TextWrapping = TextWrapping.Wrap };
    private readonly ToggleLever _leverClock = new(), _leverSensing = new(), _leverLogin = new();
    private readonly NixieCounter _nixie = new();
    private readonly TextBlock _nixieLabel = Brass.EngravedText("", 8);
    private readonly LanguageSelector _langSel = new();
    private readonly BrassButton _quit = new("", "");
    private readonly TextBlock _windowHint = new() { FontFamily = Brass.Typewriter, FontSize = 10, Foreground = Brass.InkBrush(0.75), TextWrapping = TextWrapping.Wrap, TextAlignment = TextAlignment.Center };
    private readonly ContextMenu _instMenu = new();

    public MainWindow(MidiBridge bridge, Settings settings)
    {
        _bridge = bridge; _settings = settings;
        _lang = Enum.TryParse<Lang>(settings.Language, true, out var l) ? l : Strings.SystemDefault();

        Title = "Piano MIDI Bridge";
        Icon = new System.Windows.Media.Imaging.BitmapImage(new Uri("pack://application:,,,/Assets/AppIcon.ico"));
        SizeToContent = SizeToContent.Height;
        Width = 520;
        ResizeMode = ResizeMode.CanMinimize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = new SolidColorBrush(Brass.WoodDark);
        UseLayoutRounding = true;
        TextOptions.SetTextFormattingMode(this, TextFormattingMode.Display);

        Content = Build();
        WireEvents();
        ApplyLanguage();
        Refresh();
        _bridge.PropertyChanged += (_, _) => Refresh();
    }

    /// Barra de título escura (Windows 10 20H1+ / 11), combinando com a madeira do painel.
    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        var hwnd = new System.Windows.Interop.WindowInteropHelper(this).Handle;
        int dark = 1;
        DwmSetWindowAttribute(hwnd, 20 /* DWMWA_USE_IMMERSIVE_DARK_MODE */, ref dark, sizeof(int));
        int caption = 0x000A1429; // COLORREF 0x00BBGGRR: madeira escura (29 14 0A)
        DwmSetWindowAttribute(hwnd, 35 /* DWMWA_CAPTION_COLOR, Windows 11 */, ref caption, sizeof(int));
    }

    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    public void ShowFromTray()
    {
        Show();
        if (WindowState == WindowState.Minimized) WindowState = WindowState.Normal;
        Activate();
    }

    /// Fechar a janela só esconde o painel: a ponte segue rodando na bandeja.
    protected override void OnClosing(CancelEventArgs e)
    {
        if (!App.Quitting) { e.Cancel = true; Hide(); App.Current.ShowTrayBalloonOnce(); }
        base.OnClosing(e);
    }

    // MARK: Montagem

    private UIElement Build()
    {
        var root = new StackPanel { Margin = new Thickness(18) };

        // cabeçalho
        var header = new DockPanel { LastChildFill = true };
        var power = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center };
        _powerLamp.HorizontalAlignment = HorizontalAlignment.Center;
        power.Children.Add(_powerLamp);
        power.Children.Add(_powerLever);
        DockPanel.SetDock(power, Dock.Right);
        _gearA.VerticalAlignment = VerticalAlignment.Center;
        _gearB.VerticalAlignment = VerticalAlignment.Center; _gearB.Margin = new Thickness(6, 0, 8, 0);
        DockPanel.SetDock(_gearA, Dock.Left);
        DockPanel.SetDock(_gearB, Dock.Right);
        header.Children.Add(_gearA);
        header.Children.Add(power);
        header.Children.Add(_gearB);
        var titles = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        var title = Brass.EngravedText("PIANO MIDI BRIDGE", 21);
        title.Foreground = Brass.InkBrush(1);
        titles.Children.Add(title);
        titles.Children.Add(_subtitle);
        header.Children.Add(titles);
        root.Children.Add(header);

        // VU meters + válvulas
        var meters = new Grid { Margin = new Thickness(0, 14, 0, 0) };
        meters.ColumnDefinitions.Add(new ColumnDefinition());
        meters.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        meters.ColumnDefinitions.Add(new ColumnDefinition());
        meters.Children.Add(Labeled(_vuOut, _vuOutLabel, 0));
        var tubes = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center };
        _tubeA.Margin = new Thickness(3, 0, 3, 0); _tubeB.Margin = new Thickness(3, 0, 3, 0);
        tubes.Children.Add(_tubeA); tubes.Children.Add(_tubeB);
        var tubesCol = new StackPanel { VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(8, 0, 8, 0) };
        tubesCol.Children.Add(tubes); _tubesLabel.Margin = new Thickness(0, 5, 0, 0); tubesCol.Children.Add(_tubesLabel);
        Grid.SetColumn(tubesCol, 1); meters.Children.Add(tubesCol);
        meters.Children.Add(Labeled(_vuIn, _vuInLabel, 2));
        root.Children.Add(meters);

        // estações
        var stations = new StackPanel();
        stations.Children.Add(StationRow(_instLamp, _instLabel, _instPlate));
        stations.Children.Add(StationRow(_txLamp, _txLabel, _txPlate));
        var rx = StationRow(_rxLamp, _rxLabel, _rxPlate);
        _openSettings.Margin = new Thickness(8, 0, 0, 0);
        ((StackPanel)rx).Children.Add(_openSettings);
        stations.Children.Add(rx);
        var hints = new StackPanel { Margin = new Thickness(28, 4, 0, 0) };
        hints.Children.Add(_hint); _notFound.Margin = new Thickness(0, 4, 0, 0); hints.Children.Add(_notFound);
        stations.Children.Add(hints);
        root.Children.Add(new Border
        {
            Margin = new Thickness(0, 14, 0, 0), Padding = new Thickness(10), CornerRadius = new CornerRadius(6),
            Background = new SolidColorBrush(Color.FromArgb(30, Brass.Ink.R, Brass.Ink.G, Brass.Ink.B)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(150, Brass.Dark.R, Brass.Dark.G, Brass.Dark.B)), BorderThickness = new Thickness(1),
            Child = stations,
        });

        // chaves + Nixie
        var switches = new DockPanel { Margin = new Thickness(0, 14, 0, 0) };
        var nixieCol = new StackPanel { VerticalAlignment = VerticalAlignment.Top };
        nixieCol.Children.Add(_nixie); _nixieLabel.Margin = new Thickness(0, 5, 0, 0); nixieCol.Children.Add(_nixieLabel);
        DockPanel.SetDock(nixieCol, Dock.Right);
        switches.Children.Add(nixieCol);
        var levers = new StackPanel { Orientation = Orientation.Horizontal };
        foreach (var lv in new[] { _leverClock, _leverSensing, _leverLogin }) { lv.Margin = new Thickness(0, 0, 18, 0); levers.Children.Add(lv); }
        switches.Children.Add(levers);
        root.Children.Add(switches);

        // rodapé
        var footer = new DockPanel { Margin = new Thickness(0, 14, 0, 0) };
        DockPanel.SetDock(_langSel, Dock.Left);
        footer.Children.Add(_langSel);
        _quit.HorizontalAlignment = HorizontalAlignment.Right; _quit.VerticalAlignment = VerticalAlignment.Center;
        footer.Children.Add(_quit);
        root.Children.Add(footer);
        _windowHint.Margin = new Thickness(0, 10, 0, 0);
        root.Children.Add(_windowHint);

        return new PanelBackground { Child = new Border { Padding = new Thickness(12), Child = root } };
    }

    private static UIElement Labeled(FrameworkElement el, TextBlock label, int col)
    {
        var s = new StackPanel { VerticalAlignment = VerticalAlignment.Bottom };
        s.Children.Add(el); label.Margin = new Thickness(0, 5, 0, 0); s.Children.Add(label);
        Grid.SetColumn(s, col);
        return s;
    }

    private static UIElement StationRow(PilotLamp lamp, TextBlock label, NamePlate plate)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 4, 0, 4) };
        lamp.VerticalAlignment = VerticalAlignment.Center;
        label.Width = 104; label.TextAlignment = TextAlignment.Left; label.Margin = new Thickness(10, 0, 0, 0); label.VerticalAlignment = VerticalAlignment.Center;
        plate.MaxWidth = 290;
        row.Children.Add(lamp); row.Children.Add(label); row.Children.Add(plate);
        return row;
    }

    // MARK: Eventos

    private void WireEvents()
    {
        _powerLever.Toggled += async on => { if (on) await _bridge.StartAsync(); else _bridge.Stop(); };
        _leverClock.Toggled += on => _bridge.FilterClock = on;
        _leverSensing.Toggled += on => _bridge.FilterActiveSensing = on;
        _leverLogin.Toggled += on => SetLaunchAtLogin(on);
        _langSel.Changed += l => { _lang = l; _settings.Language = l.ToString(); _settings.Save(); ApplyLanguage(); Refresh(); };
        _quit.Click += (_, _) => App.Current.Quit();
        _openSettings.Click += (_, _) => Process.Start(new ProcessStartInfo("ms-settings:bluetooth") { UseShellExecute = true });
        _instPlate.Cursor = Cursors.Hand;
        _instPlate.ContextMenu = _instMenu;
        _instPlate.MouseLeftButtonUp += (_, _) =>
        {
            _instMenu.Items.Clear();
            foreach (var d in _bridge.Instruments)
            {
                var item = new MenuItem { Header = d.Name, IsChecked = d.InId == _bridge.Piano?.InId };
                item.Click += async (_, _) => await _bridge.SelectPianoAsync(d);
                _instMenu.Items.Add(item);
            }
            if (_instMenu.Items.Count > 0) { _instMenu.PlacementTarget = _instPlate; _instMenu.IsOpen = true; }
        };
    }

    private void ApplyLanguage()
    {
        var t = T;
        _subtitle.Text = t.Subtitle;
        _powerLever.Title = t.Power;
        _powerLever.ToolTip = _bridge.IsRunning ? t.PowerOff : t.PowerOn;
        _vuOutLabel.Text = t.ToPhone; _vuInLabel.Text = t.ToPiano; _tubesLabel.Text = t.Tubes;
        _instLabel.Text = t.Instrument; _txLabel.Text = t.Transmitter; _rxLabel.Text = t.Receiver;
        _leverClock.Title = t.FilterClock; _leverSensing.Title = t.FilterSensing; _leverLogin.Title = t.LaunchAtLogin;
        _nixieLabel.Text = t.BytesFiltered;
        _quit.SetTitle(t.Quit);
        _openSettings.SetTitle(t.OpenSettings);
        _langSel.Set(_lang, t.Language);
        _windowHint.Text = t.WindowHint;
        App.Current.UpdateTrayTexts(t);
    }

    private void Refresh()
    {
        var t = T;
        bool active = _bridge.IsRunning;
        _gearA.Spinning = active; _gearB.Spinning = active;
        _powerLamp.Lit = active; _powerLever.IsOn = active;
        _powerLever.ToolTip = active ? t.PowerOff : t.PowerOn;

        static double Activity(double rate) => Math.Min(1, Math.Log10(1 + rate) / Math.Log10(1 + 2000));
        _vuOut.SetTarget(active ? Activity(_bridge.RateToDevice) : 0);
        _vuIn.SetTarget(active ? Activity(_bridge.RateToPiano) : 0);
        _tubeA.Power = active ? 0.45 + Activity(_bridge.RateToDevice) * 0.55 : 0;
        _tubeB.Power = active ? 0.45 + Activity(_bridge.RateToPiano) * 0.55 : 0;

        // instrumento
        _instLamp.Lit = active; _instLamp.Color = _bridge.Piano != null ? Colors.LimeGreen : Colors.Red;
        if (_bridge.Instruments.Count == 0) _instPlate.Set(t.ConnectUsb, dim: true);
        else _instPlate.Set((_bridge.Piano?.Name ?? t.Select) + "  ▾");

        // transmissor
        var st = _bridge.BleStatus;
        _txLamp.Lit = active;
        _txLamp.Color = st is BleStatus.Advertising or BleStatus.Connected ? Colors.LimeGreen
                      : st is BleStatus.Starting or BleStatus.Idle ? Colors.Orange : Colors.Red;
        _txLamp.Blinking = st == BleStatus.Advertising;
        _txPlate.Set(Environment.MachineName);
        _txPlate.ToolTip = t.TransmitterName;

        // receptor
        _rxLamp.Lit = active; _rxLamp.Color = _bridge.IsLinked ? Colors.LimeGreen : Colors.Orange;
        _openSettings.Visibility = Visibility.Collapsed;
        switch (st)
        {
            case BleStatus.Off: _rxPlate.Set(t.BtOff, dim: true); _openSettings.Visibility = Visibility.Visible; break;
            case BleStatus.Unsupported: _rxPlate.Set(t.BtUnsupported, dim: true); break;
            case BleStatus.Error: _rxPlate.Set(t.BtError, dim: true); break;
            case BleStatus.Connected: _rxPlate.Set(t.PhoneConnected); break;
            default: _rxPlate.Set(t.WaitingPhone, dim: true); break;
        }

        bool waiting = active && st == BleStatus.Advertising;
        _hint.Visibility = _notFound.Visibility = waiting ? Visibility.Visible : Visibility.Collapsed;
        _hint.Text = string.Format(t.ConnectHint, Environment.MachineName);
        _notFound.Text = t.NotFoundHint;

        _leverClock.IsOn = _bridge.FilterClock;
        _leverSensing.IsOn = _bridge.FilterActiveSensing;
        _leverLogin.IsOn = IsLaunchAtLogin();
        _nixie.Set(_bridge.Filtered, active);
    }

    // MARK: Ligar com o Windows (HKCU\...\Run)

    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

    private static bool IsLaunchAtLogin()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue("PianoMidiBridge") != null;
    }

    private static void SetLaunchAtLogin(bool on)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey);
        if (on) key.SetValue("PianoMidiBridge", $"\"{Environment.ProcessPath}\" --tray");
        else key.DeleteValue("PianoMidiBridge", false);
        DiagLog.Write($"Ligar com o Windows: {on}");
    }
}
