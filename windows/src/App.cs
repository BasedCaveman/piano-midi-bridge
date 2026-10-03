// Ponto de entrada: instância única, ícone na bandeja e ciclo de vida da ponte.
using System.Windows;
using PianoMidiBridge.Engine;
using PianoMidiBridge.UI;
using Forms = System.Windows.Forms;

namespace PianoMidiBridge;

public sealed class App : Application
{
    public static new App Current => (App)Application.Current;
    public static bool Quitting { get; private set; }

    private const string MutexName = "PianoMidiBridge.SingleInstance";
    private const string ShowEventName = "PianoMidiBridge.Show";

    private Settings _settings = null!;
    private MidiBridge _bridge = null!;
    private MainWindow _window = null!;
    private Forms.NotifyIcon? _tray;
    private Forms.ToolStripMenuItem? _trayOpen, _trayQuit;
    private bool _balloonShown;
    private string _balloonText = "";

    [STAThread]
    public static void Main(string[] args)
    {
        // Só uma cópia: se já houver uma rodando, pede para ela mostrar o painel e sai.
        using var mutex = new Mutex(true, MutexName, out bool first);
        if (!first)
        {
            try { EventWaitHandle.OpenExisting(ShowEventName).Set(); } catch { /* a outra cópia está encerrando */ }
            return;
        }
        var app = new App { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        app.Run(args);
    }

    private void Run(string[] args)
    {
        Startup += async (_, _) =>
        {
            DispatcherUnhandledException += (_, e) => { DiagLog.Write("Erro não tratado: " + e.Exception); e.Handled = true; };
            _settings = Settings.Load();
            _bridge = new MidiBridge(_settings);
            _window = new MainWindow(_bridge, _settings);
            CreateTray();
            ListenForShowRequests();
            // Ao ligar com o Windows (--tray) começa só na bandeja.
            if (!args.Contains("--tray")) _window.ShowFromTray();
            await _bridge.InitializeAsync();
        };
        base.Run();
    }

    private void ListenForShowRequests()
    {
        var evt = new EventWaitHandle(false, EventResetMode.AutoReset, ShowEventName);
        var thread = new Thread(() =>
        {
            while (evt.WaitOne()) Dispatcher.Invoke(() => _window.ShowFromTray());
        }) { IsBackground = true };
        thread.Start();
    }

    private void CreateTray()
    {
        var iconStream = GetResourceStream(new Uri("pack://application:,,,/Assets/AppIcon.ico"))!.Stream;
        _trayOpen = new Forms.ToolStripMenuItem("", null, (_, _) => _window.ShowFromTray());
        _trayQuit = new Forms.ToolStripMenuItem("", null, (_, _) => Quit());
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add(_trayOpen);
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(_trayQuit);
        _tray = new Forms.NotifyIcon
        {
            Icon = new System.Drawing.Icon(iconStream),
            Text = "Piano MIDI Bridge",
            Visible = true,
            ContextMenuStrip = menu,
        };
        _tray.MouseClick += (_, e) => { if (e.Button == Forms.MouseButtons.Left) _window.ShowFromTray(); };
    }

    public void UpdateTrayTexts(Strings t)
    {
        if (_trayOpen != null) _trayOpen.Text = t.TrayOpen;
        if (_trayQuit != null) _trayQuit.Text = t.TrayQuit;
        _balloonText = t.TrayRunning;
    }

    /// Na primeira vez que o painel é fechado, avisa que a ponte continua na bandeja.
    public void ShowTrayBalloonOnce()
    {
        if (_balloonShown || _tray == null) return;
        _balloonShown = true;
        _tray.ShowBalloonTip(4000, "Piano MIDI Bridge", _balloonText, Forms.ToolTipIcon.Info);
    }

    public void Quit()
    {
        Quitting = true;
        DiagLog.Write("App encerrado");
        _bridge.Dispose();
        if (_tray != null) { _tray.Visible = false; _tray.Dispose(); }
        Shutdown();
    }
}
