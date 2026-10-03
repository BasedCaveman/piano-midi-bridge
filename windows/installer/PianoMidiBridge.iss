; Instalador do Piano MIDI Bridge para Windows (Inno Setup 6).
; Compilado pelo GitHub Actions:  iscc /DAppVersion=1.0.0 /DArch=x64 /DSourceDir=..\publish\x64 PianoMidiBridge.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef Arch
  #define Arch "x64"
#endif
#ifndef SourceDir
  #define SourceDir "..\publish\" + Arch
#endif

[Setup]
AppId={{6C1F3E2A-8B54-4C7E-9D2F-5A1B7E3C9F04}
AppName=Piano MIDI Bridge
AppVersion={#AppVersion}
AppPublisher=Piano MIDI Bridge contributors
AppPublisherURL=https://github.com/BasedCaveman/piano-midi-bridge
AppSupportURL=https://github.com/BasedCaveman/piano-midi-bridge/issues
DefaultDirName={autopf}\Piano MIDI Bridge
DefaultGroupName=Piano MIDI Bridge
DisableProgramGroupPage=yes
; Instala só para o usuário atual: não pede administrador
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\dist
OutputBaseFilename=PianoMIDIBridge-Setup-{#AppVersion}-{#Arch}
SetupIconFile=..\src\Assets\AppIcon.ico
UninstallDisplayIcon={app}\PianoMidiBridge.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
MinVersion=10.0.19041
#if Arch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif

[Languages]
Name: "pt"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[CustomMessages]
pt.StartWithWindows=Iniciar com o Windows
en.StartWithWindows=Start with Windows
es.StartWithWindows=Iniciar con Windows

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startup"; Description: "{cm:StartWithWindows}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\Piano MIDI Bridge"; Filename: "{app}\PianoMidiBridge.exe"
Name: "{autodesktop}\Piano MIDI Bridge"; Filename: "{app}\PianoMidiBridge.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "PianoMidiBridge"; \
  ValueData: """{app}\PianoMidiBridge.exe"" --tray"; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{app}\PianoMidiBridge.exe"; Description: "{cm:LaunchProgram,Piano MIDI Bridge}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /IM PianoMidiBridge.exe /F"; Flags: runhidden; RunOnceId: "KillApp"

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\PianoMidiBridge"
