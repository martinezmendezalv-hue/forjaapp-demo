; Instalador de la demo de ForjaApp (Inno Setup 6)

[Setup]
AppId={{8C3F2E1A-5B7D-4F2A-9C1E-FA11F0A1D2B3}
AppName=ForjaApp Demo
AppVersion=1.0.0
AppPublisher=Alvaro Martinez - 2 DAM
DefaultDirName={autopf}\ForjaApp Demo
DefaultGroupName=ForjaApp Demo
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=ForjaApp-Demo-Setup
SetupIconFile=..\assets\forja.ico
UninstallDisplayIcon={app}\forja_app_demo.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\ForjaApp Demo"; Filename: "{app}\forja_app_demo.exe"
Name: "{autodesktop}\ForjaApp Demo"; Filename: "{app}\forja_app_demo.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\forja_app_demo.exe"; Description: "Abrir ForjaApp Demo"; Flags: nowait postinstall skipifsilent
; Al actualizarse sola (instalación silenciosa) la app se vuelve a abrir.
Filename: "{app}\forja_app_demo.exe"; Flags: nowait; Check: WizardSilent
