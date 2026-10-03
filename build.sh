#!/bin/bash
# Gera build/Piano MIDI Bridge.app (universal) e build/PianoMIDIBridge-<versão>.dmg
# Requer apenas as Command Line Tools: xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-1.0.0}"
APP_NAME="Piano MIDI Bridge"
BUILD=build
APP="$BUILD/$APP_NAME.app"
MIN_OS=14.0

rm -rf "$BUILD" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▸ Compilando (arm64 + x86_64)…"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos$MIN_OS" \
    -framework CoreMIDI -framework CoreAudioKit -framework ServiceManagement \
    Sources/*.swift -o "$BUILD/PianoMIDIBridge-$arch" 2>&1 | grep -v "warning:.*deprecated" || true
  test -f "$BUILD/PianoMIDIBridge-$arch"
done
lipo -create "$BUILD"/PianoMIDIBridge-{arm64,x86_64} -output "$APP/Contents/MacOS/PianoMIDIBridge"
rm "$BUILD"/PianoMIDIBridge-{arm64,x86_64}

echo "▸ Montando o .app…"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
# Ícone: gera todos os tamanhos a partir do mestre de 1024 px
ICONSET="$BUILD/AppIcon.iconset"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$BUILD/AppIcon.iconset"

echo "▸ Assinando…"
# Sem DEVELOPER_ID, usa assinatura ad-hoc (o usuário precisa liberar no Gatekeeper na 1ª abertura).
codesign --force --deep --options runtime --sign "${DEVELOPER_ID:--}" "$APP"

echo "▸ Criando DMG…"
STAGE="$BUILD/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp docs/*.txt "$STAGE/"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$BUILD/PianoMIDIBridge-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

echo "✔ Pronto:"
echo "   $APP"
echo "   $BUILD/PianoMIDIBridge-$VERSION.dmg"
