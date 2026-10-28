; Instalador de ForjaApp Servidor (Inno Setup 6)
; La base de datos y la API del gimnasio. Incluye la versión web de la app,
; que el servidor sirve en http://<IP del PC>:8080

[Setup]
AppId={{4E2B9A7C-1D3F-4B8E-A6C2-5F0D9E3B7A11}
AppName=ForjaApp Servidor
AppVersion=1.0.0
AppPublisher=Alvaro Martinez - 2 DAM
DefaultDirName={autopf}\ForjaApp Servidor
DefaultGroupName=ForjaApp Servidor
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=ForjaApp-Servidor-Setup
SetupIconFile=..\assets\forja.ico
UninstallDisplayIcon={app}\forja_servidor.exe
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
Source: "..\servidor\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\ForjaApp Servidor"; Filename: "{app}\forja_servidor.exe"
Name: "{autodesktop}\ForjaApp Servidor"; Filename: "{app}\forja_servidor.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\forja_servidor.exe"; Description: "Abrir ForjaApp Servidor"; Flags: nowait postinstall skipifsilent
