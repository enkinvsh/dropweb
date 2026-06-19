[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={{INSTALL_DIR_NAME}}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
WizardStyle=modern
PrivilegesRequired={{PRIVILEGES_REQUIRED}}
ArchitecturesAllowed={{ARCH}}
ArchitecturesInstallIn64BitMode={{ARCH}}
UninstallDisplayIcon={uninstallexe}
ChangesAssociations=yes
; Update mode settings
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes

[Code]
const
  SHCNE_ASSOCCHANGED = $08000000;
  SHCNF_IDLIST = $0000;

var
  IsUpgrade: Boolean;
  PreviousVersion: String;

procedure SHChangeNotify(wEventId: Integer; uFlags: Integer; dwItem1: Integer; dwItem2: Integer); external 'SHChangeNotify@shell32.dll stdcall';

procedure KillProcesses;
var
  Processes: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  // dropweb lineage: current names, the FlClash upstream names that older
  // dropweb builds shipped under our identity, and Koala Clash. Killing these
  // by name during install is transient/recoverable and frees the global
  // resources (mixed-port 7890, TUN, system proxy) so a clean install settles.
  Processes := ['dropweb.exe', 'DropwebCore.exe', 'DropwebHelperService.exe',
                'FlClashX.exe', 'FlClashCore.exe', 'FlClashHelperService.exe',
                'FlClash.exe', 'koala-clash-service.exe', 'KoalaClash.exe'];

  // First try graceful shutdown
  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    Exec('taskkill', '/im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
  
  // Wait for processes to terminate gracefully
  Sleep(1000);

  // Force kill any remaining processes
  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    Exec('taskkill', '/f /im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
  
  // Give time for cleanup
  Sleep(1000);
end;

function IsAppInstalled(): Boolean;
var
  UninstallKey: String;
begin
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{APP_ID}}_is1';
  Result := RegKeyExists(HKEY_LOCAL_MACHINE, UninstallKey) or 
            RegKeyExists(HKEY_CURRENT_USER, UninstallKey);
end;

function IsUpgradeInstallation(): Boolean;
begin
  Result := IsUpgrade;
end;

function GetInstalledVersion(): String;
var
  UninstallKey: String;
  Version: String;
begin
  Result := '';
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{APP_ID}}_is1';
  
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, UninstallKey, 'DisplayVersion', Version) then
    Result := Version
  else if RegQueryStringValue(HKEY_CURRENT_USER, UninstallKey, 'DisplayVersion', Version) then
    Result := Version;
end;

// --- Clean-install helpers ---------------------------------------------------
// All "ours-only" gated: a leftover is removed only when it lives inside OUR
// install dir ({app}). A separately installed real FlClashX (in its own folder)
// is therefore never touched.

function ServiceBelongsToApp(ServiceName: String): Boolean;
var
  TmpFile: String;
  Output: AnsiString;
  ResultCode: Integer;
  AppDir: String;
begin
  Result := False;
  AppDir := ExpandConstant('{app}');
  TmpFile := ExpandConstant('{tmp}\dwsvc_qc.txt');
  if Exec(ExpandConstant('{cmd}'), '/c sc qc "' + ServiceName + '" > "' + TmpFile + '" 2>&1', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if LoadStringFromFile(TmpFile, Output) then
      Result := Pos(Lowercase(AppDir), Lowercase(String(Output))) > 0;
  end;
end;

procedure RemoveServiceIfOurs(ServiceName: String);
var
  ResultCode: Integer;
begin
  if ServiceBelongsToApp(ServiceName) then
  begin
    Exec('sc.exe', 'stop "' + ServiceName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(500);
    Exec('sc.exe', 'delete "' + ServiceName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(300);
  end;
end;

procedure RemoveRunValueIfOurs(RootKey: Integer; ValueName: String);
var
  Data: String;
  AppDir: String;
begin
  AppDir := ExpandConstant('{app}');
  if RegQueryStringValue(RootKey, 'Software\Microsoft\Windows\CurrentVersion\Run', ValueName, Data) then
  begin
    if Pos(Lowercase(AppDir), Lowercase(Data)) > 0 then
      RegDeleteValue(RootKey, 'Software\Microsoft\Windows\CurrentVersion\Run', ValueName);
  end;
end;

function TaskBelongsToApp(TaskName: String): Boolean;
var
  TmpFile: String;
  Output: AnsiString;
  ResultCode: Integer;
  AppDir: String;
begin
  Result := False;
  AppDir := ExpandConstant('{app}');
  TmpFile := ExpandConstant('{tmp}\dwtask_q.txt');
  if Exec(ExpandConstant('{cmd}'), '/c schtasks /Query /TN "' + TaskName + '" /XML > "' + TmpFile + '" 2>&1', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if (ResultCode = 0) and LoadStringFromFile(TmpFile, Output) then
      Result := Pos(Lowercase(AppDir), Lowercase(String(Output))) > 0;
  end;
end;

procedure RemoveTaskIfOurs(TaskName: String);
var
  ResultCode: Integer;
begin
  if TaskBelongsToApp(TaskName) then
    Exec(ExpandConstant('{cmd}'), '/c schtasks /Delete /TN "' + TaskName + '" /F', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

procedure CleanLineageLeftovers;
var
  i: Integer;
  Services: TArrayOfString;
  RunValues: TArrayOfString;
  Tasks: TArrayOfString;
begin
  // Stale Windows services from older / pre-rebrand builds whose binaries live
  // inside OUR install dir. DropwebHelperService is intentionally NOT listed —
  // it is the current service (re-copied by [Files], restarted post-install).
  Services := ['FlClashHelperService', 'FlClashXHelperService', 'ClashHelperService', 'clashx'];
  for i := 0 to GetArrayLength(Services)-1 do
    RemoveServiceIfOurs(Services[i]);

  // Stale autostart (Run key) entries pointing into our install dir.
  RunValues := ['FlClash', 'FlClashX', 'clashx', 'clash', 'com.follow'];
  for i := 0 to GetArrayLength(RunValues)-1 do
  begin
    RemoveRunValueIfOurs(HKEY_CURRENT_USER, RunValues[i]);
    RemoveRunValueIfOurs(HKEY_LOCAL_MACHINE, RunValues[i]);
  end;

  // Stale scheduled tasks pointing into our install dir.
  Tasks := ['FlClash', 'FlClashX', 'clashx', 'clash'];
  for i := 0 to GetArrayLength(Tasks)-1 do
    RemoveTaskIfOurs(Tasks[i]);
end;
// --- end clean-install helpers ----------------------------------------------

function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // Check if app is already installed
  IsUpgrade := IsAppInstalled();
  if IsUpgrade then
    PreviousVersion := GetInstalledVersion();
  
   // Stop service if running
   Exec('sc.exe', 'stop "DropwebHelperService"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(1000);
  
  // Kill all processes
  KillProcesses;
  
  Result := True;
end;

procedure InitializeWizard();
begin
  if IsUpgrade then
  begin
    WizardForm.Caption := '{{DISPLAY_NAME}} - Обновление';
    if PreviousVersion <> '' then
      WizardForm.WelcomeLabel2.Caption := 
        'Обнаружена установленная версия ' + PreviousVersion + '.' + #13#10 + #13#10 +
        'Программа установит версию {{APP_VERSION}}.' + #13#10 + #13#10 +
        'Нажмите «Далее», чтобы продолжить обновление, или «Отмена», чтобы выйти.'
    else
      WizardForm.WelcomeLabel2.Caption := 
        'Обнаружена установленная версия программы.' + #13#10 + #13#10 +
        'Программа установит версию {{APP_VERSION}}.' + #13#10 + #13#10 +
        'Нажмите «Далее», чтобы продолжить обновление, или «Отмена», чтобы выйти.';
  end;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  if IsUpgrade then
  begin
    Result := 'Обновление' + NewLine;
    if PreviousVersion <> '' then
      Result := Result + 'Текущая версия: ' + PreviousVersion + NewLine;
    Result := Result + 'Новая версия: {{APP_VERSION}}' + NewLine + NewLine;
  end
  else
    Result := 'Новая установка' + NewLine + NewLine;
    
  if MemoDirInfo <> '' then
    Result := Result + MemoDirInfo + NewLine + NewLine;
  if MemoGroupInfo <> '' then
    Result := Result + MemoGroupInfo + NewLine + NewLine;
  if MemoTasksInfo <> '' then
    Result := Result + MemoTasksInfo + NewLine;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  LegacyDir: String;
begin
  if CurStep = ssInstall then
  begin
    // CLEAN INSTALL (Tier 1): runs before [InstallDelete] wipes {app} and
    // before [Files] copies fresh binaries ({app} is resolved by now).
    // Stop our service so its .exe unlocks for the wipe; ssPostInstall restarts it.
    Exec('sc.exe', 'stop "DropwebHelperService"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(500);
    KillProcesses;
    // Drop stale services / autostart from older or pre-rebrand builds that
    // live inside our install dir (a separate FlClashX elsewhere is untouched).
    CleanLineageLeftovers;
  end;

  if CurStep = ssPostInstall then
  begin
    // Refresh icon cache/associations
    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, 0, 0);
    Sleep(500);
     // Ensure helper service is started after install/upgrade, independent of app
     try
       Exec('sc.exe', 'start "DropwebHelperService"', '', SW_HIDE, ewNoWait, ResultCode);
    except
    end;

    // CLEAN INSTALL (Tier 2): offer to remove legacy-identity data left by
    // pre-rebrand builds (%APPDATA%\com.follow\clashx). Current profiles and
    // settings (%APPDATA%\dropweb\dropweb) are NOT touched. Skipped on silent.
    LegacyDir := ExpandConstant('{userappdata}\com.follow\clashx');
    if DirExists(LegacyDir) and (not WizardSilent) then
    begin
      if MsgBox('Обнаружены данные от старой версии dropweb (com.follow\clashx).' + #13#10 +
                'Удалить их? Текущие профили и настройки не пострадают.',
                mbConfirmation, MB_YESNO) = IDYES then
      begin
        DelTree(LegacyDir, True, True, True);
        RemoveDir(ExpandConstant('{userappdata}\com.follow'));
      end;
    end;
  end;
end;

function GetSchemeCommand(Scheme: String): String;
var
  CmdValue: String;
  RegPath: String;
begin
  Result := '';
  RegPath := 'Software\Classes\' + Scheme + '\shell\open\command';
  if RegQueryStringValue(HKEY_CURRENT_USER, RegPath, '', CmdValue) then
    Result := CmdValue;
end;

function IsSchemeOurs(Scheme: String): Boolean;
var
  Cmd: String;
  OurExe: String;
begin
  Cmd := GetSchemeCommand(Scheme);
  OurExe := ExpandConstant('{app}\dropweb.exe');
  // Case-insensitive substring check — Inno's Pos is case-sensitive, so
  // lowercase both sides first.
  Result := (Cmd <> '') and (Pos(Lowercase(OurExe), Lowercase(Cmd)) > 0);
end;

procedure RemoveSchemeIfOurs(Scheme: String);
begin
  if IsSchemeOurs(Scheme) then
    RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\Classes\' + Scheme);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  case CurUninstallStep of
     usUninstall:
     begin
       // Stop service first
       Exec('sc.exe', 'stop "DropwebHelperService"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(1000);
      
      // Kill all processes
      KillProcesses;
      
       // Delete service
       Exec('sc.exe', 'delete "DropwebHelperService"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(500);
    end;
    
    usPostUninstall:
    begin
      // Remove our own protocol handlers. For the shared schemes (flclash,
      // clashx) only remove them if they still point to our exe — otherwise
      // we'd accidentally kill FlClashX's legitimate handler.
      RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\Classes\dropweb');
      RemoveSchemeIfOurs('flclash');
      RemoveSchemeIfOurs('clashx');

      if DirExists(ExpandConstant('{userappdata}\dropweb\dropweb')) then
      begin
        if MsgBox('Удалить пользовательские данные программы?', mbConfirmation, MB_YESNO) = IDYES then
        begin
          DelTree(ExpandConstant('{userappdata}\dropweb\dropweb'), True, True, True);
        end;
      end;
    end;
  end;
end;
[Languages]
{% for locale in LOCALES %}
{% if locale.lang == 'en' %}Name: "english"; MessagesFile: "compiler:Default.isl"{% endif %}
{% if locale.lang == 'hy' %}Name: "armenian"; MessagesFile: "compiler:Languages\\Armenian.isl"{% endif %}
{% if locale.lang == 'bg' %}Name: "bulgarian"; MessagesFile: "compiler:Languages\\Bulgarian.isl"{% endif %}
{% if locale.lang == 'ca' %}Name: "catalan"; MessagesFile: "compiler:Languages\\Catalan.isl"{% endif %}
{% if locale.lang == 'zh' %}
Name: "chineseSimplified"; MessagesFile: {% if locale.file %}{{ locale.file }}{% else %}"compiler:Languages\\ChineseSimplified.isl"{% endif %}
{% endif %}
{% if locale.lang == 'co' %}Name: "corsican"; MessagesFile: "compiler:Languages\\Corsican.isl"{% endif %}
{% if locale.lang == 'cs' %}Name: "czech"; MessagesFile: "compiler:Languages\\Czech.isl"{% endif %}
{% if locale.lang == 'da' %}Name: "danish"; MessagesFile: "compiler:Languages\\Danish.isl"{% endif %}
{% if locale.lang == 'nl' %}Name: "dutch"; MessagesFile: "compiler:Languages\\Dutch.isl"{% endif %}
{% if locale.lang == 'fi' %}Name: "finnish"; MessagesFile: "compiler:Languages\\Finnish.isl"{% endif %}
{% if locale.lang == 'fr' %}Name: "french"; MessagesFile: "compiler:Languages\\French.isl"{% endif %}
{% if locale.lang == 'de' %}Name: "german"; MessagesFile: "compiler:Languages\\German.isl"{% endif %}
{% if locale.lang == 'he' %}Name: "hebrew"; MessagesFile: "compiler:Languages\\Hebrew.isl"{% endif %}
{% if locale.lang == 'is' %}Name: "icelandic"; MessagesFile: "compiler:Languages\\Icelandic.isl"{% endif %}
{% if locale.lang == 'it' %}Name: "italian"; MessagesFile: "compiler:Languages\\Italian.isl"{% endif %}
{% if locale.lang == 'ja' %}Name: "japanese"; MessagesFile: "compiler:Languages\\Japanese.isl"{% endif %}
{% if locale.lang == 'no' %}Name: "norwegian"; MessagesFile: "compiler:Languages\\Norwegian.isl"{% endif %}
{% if locale.lang == 'pl' %}Name: "polish"; MessagesFile: "compiler:Languages\\Polish.isl"{% endif %}
{% if locale.lang == 'pt' %}Name: "portuguese"; MessagesFile: "compiler:Languages\\Portuguese.isl"{% endif %}
{% if locale.lang == 'ru' %}Name: "russian"; MessagesFile: "compiler:Languages\\Russian.isl"{% endif %}
{% if locale.lang == 'sk' %}Name: "slovak"; MessagesFile: "compiler:Languages\\Slovak.isl"{% endif %}
{% if locale.lang == 'sl' %}Name: "slovenian"; MessagesFile: "compiler:Languages\\Slovenian.isl"{% endif %}
{% if locale.lang == 'es' %}Name: "spanish"; MessagesFile: "compiler:Languages\\Spanish.isl"{% endif %}
{% if locale.lang == 'tr' %}Name: "turkish"; MessagesFile: "compiler:Languages\\Turkish.isl"{% endif %}
{% if locale.lang == 'uk' %}Name: "ukrainian"; MessagesFile: "compiler:Languages\\Ukrainian.isl"{% endif %}
{% endfor %}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
[InstallDelete]
; CLEAN INSTALL (Tier 1): empty the install dir before copying fresh files so
; orphaned binaries from previous builds (incl. FlClash-branded cores/helpers)
; do not survive. {app} holds only program files — user data lives in %APPDATA%
; and is untouched. Processed after CurStepChanged(ssInstall) and before [Files].
Type: filesandordirs; Name: "{app}\*"
[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon
[Run]
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: {% if PRIVILEGES_REQUIRED == 'admin' %}runascurrentuser{% endif %} nowait postinstall skipifsilent