// Controles do painel steampunk (mesmo visual da versão macOS): moldura de madeira,
// placa de latão, válvulas, VU meters, engrenagens, chaves de alavanca e Nixie.
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Threading;

namespace PianoMidiBridge.UI;

public static class Brass
{
    public static readonly Color Light = Color.FromRgb(0xED, 0xC7, 0x78);
    public static readonly Color Mid = Color.FromRgb(0xC2, 0x94, 0x4A);
    public static readonly Color Dark = Color.FromRgb(0x75, 0x52, 0x21);
    public static readonly Color Copper = Color.FromRgb(0xB8, 0x6B, 0x38);
    public static readonly Color Ink = Color.FromRgb(0x33, 0x1F, 0x0D);
    public static readonly Color WoodLight = Color.FromRgb(0x5C, 0x33, 0x1A);
    public static readonly Color WoodDark = Color.FromRgb(0x29, 0x14, 0x0A);
    public static readonly Color Glow = Color.FromRgb(0xFF, 0x8C, 0x26);
    public static readonly Color Cream = Color.FromRgb(0xF5, 0xE8, 0xC7);
    public static readonly Color PlateDark = Color.FromRgb(0x1F, 0x12, 0x0A);

    public static readonly FontFamily Engraved = new(new Uri("pack://application:,,,/"), "./Assets/Fonts/#Cinzel");
    public static readonly FontFamily Typewriter = new(new Uri("pack://application:,,,/"), "./Assets/Fonts/#Special Elite");

    public static Brush Metal => new LinearGradientBrush(new GradientStopCollection
        { new(Light, 0), new(Mid, 0.55), new(Dark, 1) }, new Point(0, 0), new Point(0, 1));

    public static Brush Plate => new LinearGradientBrush(new GradientStopCollection
        { new(Light, 0), new(Mid, 0.4), new(Color.FromRgb(0xD9, 0xAD, 0x61), 0.7), new(Dark, 1) }, new Point(0, 0), new Point(1, 1));

    public static Brush InkBrush(double opacity = 0.85) => new SolidColorBrush(Color.FromArgb((byte)(opacity * 255), Ink.R, Ink.G, Ink.B));

    /// Texto "gravado" no latão: escuro com realce claro abaixo.
    public static TextBlock EngravedText(string text, double size, double tracking = 1.2) => new()
    {
        Text = text,
        FontFamily = Engraved,
        FontWeight = FontWeights.Bold,
        FontSize = size,
        Foreground = InkBrush(),
        TextAlignment = TextAlignment.Center,
        Effect = new DropShadowEffect { Color = Colors.White, Opacity = 0.45, BlurRadius = 0, ShadowDepth = 1, Direction = 270 },
    };
}

/// Moldura de madeira + placa de latão escovada com rebites.
public sealed class PanelBackground : Decorator
{
    protected override void OnRender(DrawingContext dc)
    {
        var w = ActualWidth; var h = ActualHeight;
        var outer = new Rect(0, 0, w, h);
        dc.DrawRoundedRectangle(new LinearGradientBrush(new GradientStopCollection
            { new(Brass.WoodLight, 0), new(Brass.WoodDark, 0.35), new(Brass.WoodLight, 0.7), new(Brass.WoodDark, 1) },
            new Point(0, 0), new Point(1, 1)), new Pen(Brushes.Black, 2), outer, 14, 14);
        // veios
        var grain = new Pen(new SolidColorBrush(Color.FromArgb(46, 0, 0, 0)), 0.8);
        dc.PushClip(new RectangleGeometry(outer, 14, 14));
        for (int i = 0; i < 40; i++)
        {
            double y = i / 40.0 * h;
            var g = new StreamGeometry();
            using (var c = g.Open())
            {
                c.BeginFigure(new Point(0, y), false, false);
                c.BezierTo(new Point(w * 0.3, y + (i % 3) * 4 - 4), new Point(w * 0.7, y - (i % 4) * 3 + 4), new Point(w, y + ((i % 5) - 2) * 3), true, false);
            }
            dc.DrawGeometry(null, i % 4 == 0 ? new Pen(grain.Brush, 1.4) : grain, g);
        }
        dc.Pop();

        // placa de latão
        var plate = new Rect(12, 12, w - 24, h - 24);
        dc.DrawRoundedRectangle(new SolidColorBrush(Color.FromArgb(120, 0, 0, 0)), null, new Rect(plate.X, plate.Y + 2, plate.Width, plate.Height), 8, 8);
        dc.DrawRoundedRectangle(Brass.Plate, new Pen(new SolidColorBrush(Brass.Dark), 2), plate, 8, 8);
        dc.PushClip(new RectangleGeometry(plate, 8, 8));
        var brushed = new Pen(new SolidColorBrush(Color.FromArgb(10, 255, 255, 255)), 1);
        var brushedStrong = new Pen(new SolidColorBrush(Color.FromArgb(16, 255, 255, 255)), 1);
        for (double y = plate.Top; y < plate.Bottom; y += 2)
            dc.DrawLine(((int)y) % 6 == 0 ? brushedStrong : brushed, new Point(plate.Left, y), new Point(plate.Right, y));
        dc.Pop();
        dc.DrawRoundedRectangle(null, new Pen(Brass.InkBrush(0.25), 0.8), new Rect(plate.Left + 5, plate.Top + 5, plate.Width - 10, plate.Height - 10), 6, 6);
        foreach (var p in new[] { new Point(plate.Left + 11, plate.Top + 11), new Point(plate.Right - 11, plate.Top + 11),
                                  new Point(plate.Left + 11, plate.Bottom - 11), new Point(plate.Right - 11, plate.Bottom - 11) })
            DrawRivet(dc, p);
    }

    public static void DrawRivet(DrawingContext dc, Point c)
    {
        dc.DrawEllipse(new SolidColorBrush(Color.FromArgb(110, 0, 0, 0)), null, new Point(c.X + 0.7, c.Y + 1.2), 4.8, 4.8);
        dc.DrawEllipse(new RadialGradientBrush(new GradientStopCollection { new(Brass.Light, 0), new(Brass.Mid, 0.6), new(Brass.Dark, 1) })
            { GradientOrigin = new Point(0.35, 0.3), Center = new Point(0.4, 0.4) }, null, c, 4.5, 4.5);
    }
}

/// Engrenagem que gira enquanto a ponte está ligada.
public sealed class Gear : FrameworkElement
{
    public static readonly DependencyProperty SpinningProperty = DependencyProperty.Register(
        nameof(Spinning), typeof(bool), typeof(Gear), new PropertyMetadata(false, (d, _) => ((Gear)d).UpdateSpin()));
    public bool Spinning { get => (bool)GetValue(SpinningProperty); set => SetValue(SpinningProperty, value); }
    public int Teeth { get; init; } = 12;
    public double Speed { get; init; } = 1;
    private readonly RotateTransform _rotate = new();

    public Gear() { RenderTransform = _rotate; RenderTransformOrigin = new Point(0.5, 0.5); }

    private void UpdateSpin()
    {
        if (Spinning)
        {
            var anim = new DoubleAnimation(0, 360 * Math.Sign(Speed), TimeSpan.FromSeconds(12 / Math.Abs(Speed))) { RepeatBehavior = RepeatBehavior.Forever };
            _rotate.BeginAnimation(RotateTransform.AngleProperty, anim);
        }
        else _rotate.BeginAnimation(RotateTransform.AngleProperty, null);
    }

    protected override void OnRender(DrawingContext dc)
    {
        double outer = Math.Min(ActualWidth, ActualHeight) / 2, inner = outer * 0.78;
        var c = new Point(ActualWidth / 2, ActualHeight / 2);
        var g = new StreamGeometry { FillRule = FillRule.EvenOdd };
        using (var ctx = g.Open())
        {
            double step = Math.PI * 2 / Teeth;
            bool first = true;
            for (int i = 0; i < Teeth; i++)
            {
                double a = i * step;
                foreach (var (ang, r) in new[] { (a, inner), (a + step * 0.15, outer), (a + step * 0.45, outer), (a + step * 0.6, inner) })
                {
                    var pt = new Point(c.X + Math.Cos(ang) * r, c.Y + Math.Sin(ang) * r);
                    if (first) { ctx.BeginFigure(pt, true, true); first = false; } else ctx.LineTo(pt, true, false);
                }
            }
            double hole = outer * 0.28;
            ctx.BeginFigure(new Point(c.X + hole, c.Y), true, true);
            ctx.ArcTo(new Point(c.X - hole, c.Y), new Size(hole, hole), 0, false, SweepDirection.Clockwise, true, false);
            ctx.ArcTo(new Point(c.X + hole, c.Y), new Size(hole, hole), 0, false, SweepDirection.Clockwise, true, false);
        }
        dc.DrawGeometry(new LinearGradientBrush(Brass.Copper, Brass.Dark, 90), new Pen(Brass.InkBrush(0.6), 0.8), g);
    }
}

/// Válvula termiônica: brilha com a ponte ligada e mais forte com o tráfego.
public sealed class VacuumTube : FrameworkElement
{
    public static readonly DependencyProperty PowerProperty = DependencyProperty.Register(
        nameof(Power), typeof(double), typeof(VacuumTube), new FrameworkPropertyMetadata(0.0, FrameworkPropertyMetadataOptions.AffectsRender));
    public double Power { get => (double)GetValue(PowerProperty); set => SetValue(PowerProperty, value); }

    public VacuumTube()
    {
        Width = 40; Height = 76;
        var flicker = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(50) };
        flicker.Tick += (_, _) => { if (Power > 0) InvalidateVisual(); };
        Loaded += (_, _) => flicker.Start();
        Unloaded += (_, _) => flicker.Stop();
    }

    protected override void OnRender(DrawingContext dc)
    {
        double t = Environment.TickCount64 / 1000.0;
        double glow = Power <= 0 ? 0 : Math.Max(0, Power + 0.06 * Math.Sin(t * 23) + 0.04 * Math.Sin(t * 7.3));
        var g = Brass.Glow;
        // halo
        dc.DrawEllipse(new RadialGradientBrush(Color.FromArgb((byte)Math.Min(255, glow * 210), g.R, g.G, g.B), Color.FromArgb(0, g.R, g.G, g.B)),
            null, new Point(20, 34), 30, 38);
        // vidro (topo arredondado)
        var glass = new Rect(4, 2, 32, 62);
        var env = new StreamGeometry();
        using (var c = env.Open())
        {
            c.BeginFigure(new Point(glass.Left, glass.Bottom), true, true);
            c.LineTo(new Point(glass.Left, glass.Top + 16), true, false);
            c.ArcTo(new Point(glass.Right, glass.Top + 16), new Size(16, 16), 0, false, SweepDirection.Clockwise, true, false);
            c.LineTo(new Point(glass.Right, glass.Bottom), true, false);
        }
        dc.DrawGeometry(new LinearGradientBrush(new GradientStopCollection
            { new(Color.FromArgb(46, 255, 255, 255), 0), new(Color.FromArgb(13, 255, 255, 255), 0.5), new(Color.FromArgb(36, 255, 255, 255), 1) },
            new Point(0, 0.5), new Point(1, 0.5)), new Pen(new SolidColorBrush(Color.FromArgb(76, 255, 255, 255)), 0.8), env);
        // placas internas
        var plateBrush = new SolidColorBrush(Color.FromRgb(90, 90, 90));
        dc.DrawRoundedRectangle(plateBrush, null, new Rect(10, 25, 7, 30), 1, 1);
        dc.DrawRoundedRectangle(plateBrush, null, new Rect(23, 25, 7, 30), 1, 1);
        // filamento
        dc.DrawRoundedRectangle(new RadialGradientBrush(Color.FromArgb((byte)Math.Min(255, glow * 230), 255, 170, 80), Color.FromArgb(0, g.R, g.G, g.B)),
            null, new Rect(5, 16, 30, 48), 15, 15);
        byte fa = (byte)Math.Min(255, 70 + glow * 185);
        dc.DrawRoundedRectangle(new LinearGradientBrush(Color.FromArgb(fa, 255, 240, 200), Color.FromArgb(fa, 255, 150, 50), 90),
            null, new Rect(17.5, 25, 5, 30), 2.5, 2.5);
        // getter e reflexo
        dc.DrawEllipse(new SolidColorBrush(Color.FromArgb(128, 190, 190, 190)), null, new Point(20, 9), 9, 3);
        dc.DrawRoundedRectangle(new SolidColorBrush(Color.FromArgb(90, 255, 255, 255)), null, new Rect(9, 14, 3, 34), 1.5, 1.5);
        // base de baquelite
        dc.DrawRoundedRectangle(new LinearGradientBrush(Color.FromRgb(51, 51, 51), Color.FromRgb(13, 13, 13), 90), null, new Rect(2, 64, 36, 12), 3, 3);
    }
}

/// VU meter analógico de ponteiro com mola.
public sealed class VuMeter : FrameworkElement
{
    public static readonly DependencyProperty LevelProperty = DependencyProperty.Register(
        nameof(Level), typeof(double), typeof(VuMeter), new FrameworkPropertyMetadata(0.0, FrameworkPropertyMetadataOptions.AffectsRender));
    public double Level { get => (double)GetValue(LevelProperty); set => SetValue(LevelProperty, value); }

    private double _target;

    public VuMeter() { Width = 150; Height = 92; }

    /// Define o alvo do ponteiro (0..1); a mola faz o movimento.
    public void SetTarget(double value)
    {
        if (Math.Abs(value - _target) < 0.01) return;
        _target = value;
        BeginAnimation(LevelProperty, new DoubleAnimation(value, TimeSpan.FromMilliseconds(450))
        { EasingFunction = new ElasticEase { Oscillations = 1, Springiness = 6, EasingMode = EasingMode.EaseOut } });
    }

    protected override void OnRender(DrawingContext dc)
    {
        var frame = new Rect(0, 0, 150, 92);
        dc.DrawRoundedRectangle(Brass.Metal, new Pen(Brass.InkBrush(0.6), 1), frame, 7, 7);
        var face = new Rect(5, 5, 140, 82);
        dc.DrawRoundedRectangle(new RadialGradientBrush(Brass.Cream, Color.FromRgb(0xED, 0xCC, 0x8C)) { Center = new Point(0.5, 1), GradientOrigin = new Point(0.5, 1), RadiusX = 1, RadiusY = 1.2 },
            null, face, 4, 4);
        dc.PushClip(new RectangleGeometry(face, 4, 4));
        var pivot = new Point(75, 84);
        double radius = 92 * 0.72;
        for (int i = 0; i <= 20; i++)
        {
            double f = i / 20.0, a = (-140 + f * 100) * Math.PI / 180;
            double r1 = radius * (i % 5 == 0 ? 0.80 : 0.86), r2 = radius * 0.94;
            dc.DrawLine(new Pen(f > 0.75 ? Brushes.Red : Brass.InkBrush(), i % 5 == 0 ? 1.4 : 0.7),
                new Point(pivot.X + Math.Cos(a) * r1, pivot.Y + Math.Sin(a) * r1),
                new Point(pivot.X + Math.Cos(a) * r2, pivot.Y + Math.Sin(a) * r2));
        }
        DrawArc(dc, pivot, radius * 0.94, -140, -65, new Pen(Brass.InkBrush(), 1));
        DrawArc(dc, pivot, radius * 0.94, -65, -40, new Pen(Brushes.Red, 2.2));
        var vu = new FormattedText("VU", System.Globalization.CultureInfo.InvariantCulture, FlowDirection.LeftToRight,
            new Typeface(Brass.Engraved, FontStyles.Normal, FontWeights.Bold, FontStretches.Normal), 11, Brass.InkBrush(0.8), 1.0);
        dc.DrawText(vu, new Point(pivot.X - vu.Width / 2, pivot.Y - radius * 0.42 - vu.Height / 2));
        // ponteiro
        double ang = (-130 + Level * 80) * Math.PI / 180;
        dc.DrawLine(new Pen(new SolidColorBrush(Color.FromRgb(38, 20, 10)), 1.6), pivot,
            new Point(pivot.X + Math.Cos(ang) * radius * 0.95, pivot.Y + Math.Sin(ang) * radius * 0.95));
        dc.DrawEllipse(Brass.Metal, null, pivot, 4.5, 4.5);
        // vidro
        dc.DrawRectangle(new LinearGradientBrush(Color.FromArgb(64, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), new Point(0, 0), new Point(0.5, 0.5)), null, face);
        dc.Pop();
    }

    private static void DrawArc(DrawingContext dc, Point c, double r, double fromDeg, double toDeg, Pen pen)
    {
        Point P(double d) => new(c.X + Math.Cos(d * Math.PI / 180) * r, c.Y + Math.Sin(d * Math.PI / 180) * r);
        var g = new StreamGeometry();
        using (var ctx = g.Open())
        {
            ctx.BeginFigure(P(fromDeg), false, false);
            ctx.ArcTo(P(toDeg), new Size(r, r), 0, false, SweepDirection.Clockwise, true, false);
        }
        dc.DrawGeometry(null, pen, g);
    }
}

/// Lâmpada-piloto com aro de latão; pode piscar.
public sealed class PilotLamp : FrameworkElement
{
    public static readonly DependencyProperty ColorProperty = DependencyProperty.Register(
        nameof(Color), typeof(Color), typeof(PilotLamp), new FrameworkPropertyMetadata(Colors.Green, FrameworkPropertyMetadataOptions.AffectsRender));
    public static readonly DependencyProperty LitProperty = DependencyProperty.Register(
        nameof(Lit), typeof(bool), typeof(PilotLamp), new FrameworkPropertyMetadata(true, FrameworkPropertyMetadataOptions.AffectsRender));
    public static readonly DependencyProperty BlinkingProperty = DependencyProperty.Register(
        nameof(Blinking), typeof(bool), typeof(PilotLamp), new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender));
    public Color Color { get => (Color)GetValue(ColorProperty); set => SetValue(ColorProperty, value); }
    public bool Lit { get => (bool)GetValue(LitProperty); set => SetValue(LitProperty, value); }
    public bool Blinking { get => (bool)GetValue(BlinkingProperty); set => SetValue(BlinkingProperty, value); }

    public PilotLamp()
    {
        Width = 18; Height = 18;
        var timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(600) };
        timer.Tick += (_, _) => { if (Blinking) InvalidateVisual(); };
        Loaded += (_, _) => timer.Start();
        Unloaded += (_, _) => timer.Stop();
    }

    protected override void OnRender(DrawingContext dc)
    {
        bool on = Lit && (!Blinking || (Environment.TickCount64 / 600) % 2 == 0);
        var c = new Point(9, 9);
        dc.DrawEllipse(Brass.Metal, null, c, 9, 9);
        if (on) dc.DrawEllipse(new RadialGradientBrush(Color.FromArgb(150, Color.R, Color.G, Color.B), Color.FromArgb(0, Color.R, Color.G, Color.B)), null, c, 12, 12);
        var core = on ? Color : Color.FromArgb(64, Color.R, Color.G, Color.B);
        dc.DrawEllipse(new RadialGradientBrush(new GradientStopCollection
            { new(on ? Color.FromArgb(230, 255, 255, 255) : Color.FromArgb(50, 255, 255, 255), 0), new(core, 0.55), new(Color.FromArgb(180, (byte)(core.R / 2), (byte)(core.G / 2), (byte)(core.B / 2)), 1) })
            { GradientOrigin = new Point(0.4, 0.35) }, null, c, 6, 6);
    }
}

/// Chave de alavanca ("bat handle") vintage com rótulos ON/OFF.
public sealed class ToggleLever : StackPanel
{
    public event Action<bool>? Toggled;
    private readonly LeverFace _face = new();
    private readonly TextBlock _on, _off, _title;
    private bool _isOn;

    private bool _initialized;
    public bool IsOn
    {
        get => _isOn;
        set
        {
            if (_initialized && _isOn == value) return; // evita reanimar a cada atualização
            _initialized = true;
            _isOn = value; _face.SetOn(value); _on.Opacity = value ? 0.9 : 0.4; _off.Opacity = value ? 0.4 : 0.9;
        }
    }
    public string Title { set => _title.Text = value; }

    public ToggleLever()
    {
        Orientation = Orientation.Vertical;
        Cursor = Cursors.Hand;
        _on = Brass.EngravedText("ON", 7.5); _off = Brass.EngravedText("OFF", 7.5);
        _title = Brass.EngravedText("", 8); _title.Margin = new Thickness(0, 3, 0, 0);
        Children.Add(_on); Children.Add(_face); Children.Add(_off); Children.Add(_title);
        Background = Brushes.Transparent;
        MouseLeftButtonUp += (_, _) => { IsOn = !IsOn; Toggled?.Invoke(IsOn); };
    }

    private sealed class LeverFace : FrameworkElement
    {
        private readonly TranslateTransform _move = new();
        private readonly Lever _lever;
        public LeverFace()
        {
            Width = 34; Height = 52;
            _lever = new Lever { RenderTransform = _move };
            AddVisualChild(_lever); AddLogicalChild(_lever);
        }
        public void SetOn(bool on) => _move.BeginAnimation(TranslateTransform.YProperty,
            new DoubleAnimation(on ? -11 : 11, TimeSpan.FromMilliseconds(180)) { EasingFunction = new BackEase { Amplitude = 0.6, EasingMode = EasingMode.EaseOut } });
        protected override int VisualChildrenCount => 1;
        protected override Visual GetVisualChild(int index) => _lever;
        protected override Size ArrangeOverride(Size s) { _lever.Arrange(new Rect(s)); return s; }
        protected override void OnRender(DrawingContext dc)
        {
            var c = new Point(17, 26);
            dc.DrawEllipse(new RadialGradientBrush(Brass.Light, Brass.Dark), new Pen(Brass.InkBrush(0.6), 1), c, 14, 14);
            dc.DrawEllipse(new SolidColorBrush(Color.FromRgb(38, 38, 38)), null, c, 5, 5);
        }
    }

    private sealed class Lever : FrameworkElement
    {
        protected override void OnRender(DrawingContext dc)
        {
            dc.DrawRoundedRectangle(new LinearGradientBrush(new GradientStopCollection
                { new(Color.FromRgb(242, 242, 242), 0), new(Color.FromRgb(140, 140, 140), 0.5), new(Color.FromRgb(204, 204, 204), 1) },
                new Point(0, 0.5), new Point(1, 0.5)), new Pen(new SolidColorBrush(Color.FromArgb(100, 0, 0, 0)), 0.5),
                new Rect(13.5, 14, 7, 24), 3.5, 3.5);
        }
    }
}

/// Plaquinha escura com texto creme (nome do instrumento, receptor…).
public sealed class NamePlate : Border
{
    private readonly TextBlock _text = new() { FontFamily = Brass.Typewriter, FontSize = 12.5, TextTrimming = TextTrimming.CharacterEllipsis };
    public NamePlate()
    {
        Background = new SolidColorBrush(Brass.PlateDark);
        BorderBrush = new SolidColorBrush(Brass.Mid);
        BorderThickness = new Thickness(1.2);
        CornerRadius = new CornerRadius(3);
        Padding = new Thickness(10, 3, 10, 3);
        Child = _text;
    }
    public void Set(string text, bool dim = false)
    {
        _text.Text = text;
        _text.Foreground = new SolidColorBrush(Color.FromArgb((byte)(dim ? 140 : 255), Brass.Cream.R, Brass.Cream.G, Brass.Cream.B));
    }
}

/// Contador Nixie com dígitos laranja.
public sealed class NixieCounter : Border
{
    private readonly TextBlock[] _digits;
    public NixieCounter(int digits = 7)
    {
        Background = Brass.Metal; CornerRadius = new CornerRadius(4); Padding = new Thickness(4);
        var row = new StackPanel { Orientation = Orientation.Horizontal };
        _digits = new TextBlock[digits];
        for (int i = 0; i < digits; i++)
        {
            _digits[i] = new TextBlock
            {
                FontFamily = new FontFamily("Consolas"), FontSize = 16, Foreground = new SolidColorBrush(Color.FromRgb(255, 153, 64)),
                HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center,
                Effect = new DropShadowEffect { Color = Brass.Glow, BlurRadius = 6, ShadowDepth = 0, Opacity = 0.9 },
            };
            row.Children.Add(new Border
            {
                Width = 15, Height = 25, Margin = new Thickness(1, 0, 1, 0),
                CornerRadius = new CornerRadius(7, 7, 2, 2),
                Background = new LinearGradientBrush(Color.FromRgb(56, 56, 56), Color.FromRgb(13, 13, 13), 90),
                BorderBrush = new SolidColorBrush(Color.FromArgb(50, 255, 255, 255)), BorderThickness = new Thickness(0.6),
                Child = _digits[i],
            });
        }
        Child = row;
    }
    public void Set(long value, bool powered)
    {
        var s = (value % (long)Math.Pow(10, _digits.Length)).ToString().PadLeft(_digits.Length, '0');
        for (int i = 0; i < _digits.Length; i++)
        {
            _digits[i].Text = s[i].ToString();
            _digits[i].Foreground = new SolidColorBrush(powered ? Color.FromRgb(255, 153, 64) : Color.FromRgb(77, 77, 77));
            _digits[i].Effect = powered ? new DropShadowEffect { Color = Brass.Glow, BlurRadius = 6, ShadowDepth = 0, Opacity = 0.9 } : null;
        }
    }
}

/// Botão de latão em cápsula.
public sealed class BrassButton : Button
{
    public BrassButton(string glyph, string title)
    {
        Cursor = Cursors.Hand;
        var content = new StackPanel { Orientation = Orientation.Horizontal };
        content.Children.Add(new TextBlock { Text = glyph, FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 11, Margin = new Thickness(0, 1, 6, 0), Foreground = Brass.InkBrush(1) });
        content.Children.Add(new TextBlock { Text = title, FontFamily = Brass.Engraved, FontWeight = FontWeights.Bold, FontSize = 10.5, Foreground = Brass.InkBrush(1) });
        Content = content;
        Template = MakeTemplate();
    }
    public void SetTitle(string title) => ((TextBlock)((StackPanel)Content).Children[1]).Text = title;

    private static ControlTemplate MakeTemplate()
    {
        var border = new FrameworkElementFactory(typeof(Border));
        border.SetValue(Border.CornerRadiusProperty, new CornerRadius(14));
        border.SetValue(Border.BackgroundProperty, Brass.Metal);
        border.SetValue(Border.BorderBrushProperty, Brass.InkBrush(0.7));
        border.SetValue(Border.BorderThicknessProperty, new Thickness(1));
        border.SetValue(Border.PaddingProperty, new Thickness(12, 6, 12, 6));
        border.SetValue(UIElement.EffectProperty, new DropShadowEffect { BlurRadius = 4, ShadowDepth = 2, Opacity = 0.45 });
        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        border.AppendChild(presenter);
        return new ControlTemplate(typeof(Button)) { VisualTree = border };
    }
}

/// Seletor de idioma: três teclas de latão, a ativa escura com brilho.
public sealed class LanguageSelector : StackPanel
{
    public event Action<Lang>? Changed;
    private readonly Dictionary<Lang, Border> _keys = new();
    private readonly TextBlock _title = Brass.EngravedText("", 7.5);

    public LanguageSelector()
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal };
        foreach (var l in new[] { Lang.Pt, Lang.En, Lang.Es })
        {
            var key = new Border
            {
                Width = 28, Height = 19, Margin = new Thickness(1.5, 0, 1.5, 0), CornerRadius = new CornerRadius(3),
                BorderBrush = Brass.InkBrush(0.6), BorderThickness = new Thickness(0.8), Cursor = Cursors.Hand,
                Child = new TextBlock { Text = l.ToString().ToUpperInvariant(), FontFamily = Brass.Engraved, FontWeight = FontWeights.Bold, FontSize = 9.5,
                    HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center },
            };
            key.MouseLeftButtonUp += (_, _) => Changed?.Invoke(l);
            _keys[l] = key; row.Children.Add(key);
        }
        Children.Add(row);
        _title.Margin = new Thickness(0, 3, 0, 0);
        Children.Add(_title);
    }

    public void Set(Lang active, string title)
    {
        _title.Text = title;
        foreach (var (l, key) in _keys)
        {
            bool on = l == active;
            key.Background = on ? new SolidColorBrush(Brass.PlateDark) : Brass.Metal;
            ((TextBlock)key.Child).Foreground = on ? new SolidColorBrush(Brass.Cream) : Brass.InkBrush(0.8);
            key.Effect = on ? new DropShadowEffect { Color = Brass.Glow, BlurRadius = 6, ShadowDepth = 0, Opacity = 0.6 } : null;
        }
    }
}
