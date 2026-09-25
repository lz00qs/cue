#ifndef AppVersion
  #error AppVersion must be supplied with /DAppVersion
#endif

[Setup]
AppId=top.hylcreative.cue
AppName=Cue
AppVersion={#AppVersion}
AppPublisher=HylCreative
AppPublisherURL=https://github.com/lz00qs/cue
AppSupportURL=https://github.com/lz00qs/cue/issues
DefaultDirName={userpf}\Cue
DefaultGroupName=Cue
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\cue.exe
SetupIconFile=..\runner\resources\app_icon.ico
OutputBaseFilename=Cue-v{#AppVersion}-windows-x64-setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Cue"; Filename: "{app}\cue.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Cue"; Filename: "{app}\cue.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\cue.exe"; Description: "Launch Cue"; Flags: nowait postinstall skipifsilent
