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
; Restart Manager: on install AND uninstall, close ONLY the applications that
; are locking files under {app} (our own running app/core/helper). This is
; path-scoped by the OS to the files Setup touches — a separately-installed
; FlClashX (in its own folder) is never detected or closed. RestartApplications
; is off so we never silently relaunch anything after the install.
CloseApplications=yes
RestartApplications=no
; Update mode settings
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes

[Code]
const
  SHCNE_ASSOCCHANGED = $08000000;
  SHCNF_IDLIST = $0000;
  HELPER_PING_TIMEOUT_MS = 15000;
  HELPER_PING_POLL_MS = 300;
  HELPER_HTTP_TIMEOUT_MS = 250;

var
  IsUpgrade: Boolean;
  PreviousVersion: String;

procedure SHChangeNotify(wEventId: Integer; uFlags: Integer; dwItem1: Integer; dwItem2: Integer); external 'SHChangeNotify@shell32.dll stdcall';

// NOTE: process shutdown is deliberately NOT done by image name. Terminating a
// process by name (dropweb.exe / DropwebCore.exe / DropwebHelperService.exe)
// would also stop a foreign binary of the same name living OUTSIDE {app}, which
// we do not own. Shutdown is handled two ways, both path/ownership scoped:
//   * our running app/core - Restart Manager (CloseApplications=yes) closes only
//     processes locking files under {app};
//   * our helper service   - an ownership-gated service stop (ServiceBelongsToApp),
//     which only ever touches a service whose binPath is inside {app}.

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
  // Path BOUNDARY: compare against "{app}\" (AddBackslash), not the bare "{app}".
  // Without the trailing separator, install dir "…\dropweb" would falsely match
  // a foreign "…\dropweb2\…" binPath (prefix collision). The trailing "\" pins
  // the match to a real directory boundary.
  AppDir := AddBackslash(ExpandConstant('{app}'));
  TmpFile := ExpandConstant('{tmp}\dwsvc_qc.txt');
  if Exec(ExpandConstant('{cmd}'), '/c sc qc "' + ServiceName + '" > "' + TmpFile + '" 2>&1', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if LoadStringFromFile(TmpFile, Output) then
      Result := Pos(Lowercase(AppDir), Lowercase(String(Output))) > 0;
  end;
end;

function ServiceExists(ServiceName: String): Boolean;
var
  ResultCode: Integer;
begin
  // `sc query` exits 0 when the service exists, 1060 (ERROR_SERVICE_DOES_NOT_EXIST)
  // when it does not. Route through cmd so we capture sc's own exit code.
  Result := False;
  if Exec(ExpandConstant('{cmd}'), '/c sc query "' + ServiceName + '" > nul 2>&1', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Result := (ResultCode = 0);
end;

function ServiceIsRunning(ServiceName: String): Boolean;
var
  TmpFile: String;
  Output: AnsiString;
  ResultCode: Integer;
begin
  Result := False;
  TmpFile := ExpandConstant('{tmp}\dwsvc_st.txt');
  if Exec(ExpandConstant('{cmd}'), '/c sc query "' + ServiceName + '" > "' + TmpFile + '" 2>&1', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if LoadStringFromFile(TmpFile, Output) then
      Result := Pos('RUNNING', Uppercase(String(Output))) > 0;
  end;
end;

function HelperPingMatchesToken(ExpectedToken: String): Boolean;
var
  Response: Variant;
  ResponseBody: String;
begin
  Result := False;
  try
    Response := CreateOleObject('WinHttp.WinHttpRequest.5.1');
    Response.SetTimeouts(HELPER_HTTP_TIMEOUT_MS, HELPER_HTTP_TIMEOUT_MS,
      HELPER_HTTP_TIMEOUT_MS, HELPER_HTTP_TIMEOUT_MS);
    Response.Open('GET', 'http://127.0.0.1:47896/ping', False);
    Response.Send;
    ResponseBody := Response.ResponseText;
    Result := (Response.Status = 200) and
      (Lowercase(Trim(ResponseBody)) = Lowercase(ExpectedToken));
  except
    // OLE creation, HTTP, and response errors mean "not ready yet". The
    // bounded caller retries and ultimately lets installation continue.
    Result := False;
  end;
end;

procedure WaitForVerifiedHelperPing;
var
  StartedAt: Cardinal;
  Elapsed: Cardinal;
  ExpectedToken: String;
begin
  StartedAt := GetTickCount;
  ExpectedToken := '';
  Log('helper ping wait start: verifying /ping against the installed core ' +
    'SHA-256 (timeout ' + IntToStr(HELPER_PING_TIMEOUT_MS) + 'ms).');

  while (GetTickCount - StartedAt) < HELPER_PING_TIMEOUT_MS do
  begin
    // setup.dart bakes this same DropwebCore.exe SHA-256 into both the helper
    // TOKEN and the app CORE_SHA256 define. Hash failures are retried because
    // AV may still have the freshly copied core locked.
    if ExpectedToken = '' then
    begin
      try
        ExpectedToken := Lowercase(
          GetSHA256OfFile(ExpandConstant('{app}\DropwebCore.exe')));
      except
        ExpectedToken := '';
      end;
    end;

    if (ExpectedToken <> '') and HelperPingMatchesToken(ExpectedToken) then
    begin
      Elapsed := GetTickCount - StartedAt;
      Log('helper ping ok after ' + IntToStr(Integer(Elapsed)) +
        'ms (verified core SHA-256).');
      Exit;
    end;

    Sleep(HELPER_PING_POLL_MS);
  end;

  Elapsed := GetTickCount - StartedAt;
  Log('helper ping timeout after ' + IntToStr(Integer(Elapsed)) +
    'ms - proceeding with app launch; app watchdog remains authoritative.');
end;

// Idempotently ensure DropwebHelperService exists, points at OUR helper exe,
// and is set to auto-start. Invoked as the [Files] AfterInstall hook on the
// helper entry (NOT ssPostInstall) so it runs inside PerformInstall: a raise
// here yields a FATAL Setup exit code 4, whereas ssPostInstall exceptions are
// swallowed by Inno (SetStep(ssPostInstall, True)).
//
//   absent            -> sc create + start          (fresh install)
//   present & ours    -> stop + sc config + start    (upgrade / repair)
//   present & foreign -> ABORT (never overwrite/delete a service we don't own)
//
// FATAL (raise -> exit 4): missing helper binary, foreign same-name service,
// sc create failure, sc config failure. NON-FATAL (log + continue): the service
// is registered but has not reached RUNNING within 15s (auto-start will bring
// it up on next boot / launch; failing here would be a false negative).
procedure EnsureHelperService;
var
  ServiceName: String;
  HelperExe: String;
  BinPathArg: String;
  ResultCode: Integer;
  i: Integer;
begin
  ServiceName := 'DropwebHelperService';
  HelperExe := ExpandConstant('{app}\DropwebHelperService.exe');

  // [Files] must have copied the helper. A missing binary means a broken
  // install — refuse to register a service pointing at a non-existent exe.
  if not FileExists(HelperExe) then
    RaiseException('Установка повреждена: не найден "' + HelperExe + '". ' +
      'Служба помощника не может быть настроена.');

  // Quote the exe for the space in "Program Files". `sc` requires a space
  // after "binPath="/"start=" and the quoted value protects the path spaces.
  BinPathArg := 'binPath= "' + HelperExe + '"';

  if ServiceExists(ServiceName) then
  begin
    if ServiceBelongsToApp(ServiceName) then
    begin
      // OURS (upgrade / repair): stop so the config takes cleanly, fix the
      // binPath (in case {app} moved) and force auto-start.
      Exec('sc.exe', 'stop "' + ServiceName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(700);
      if not Exec('sc.exe', 'config "' + ServiceName + '" ' + BinPathArg + ' start= auto', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) or (ResultCode <> 0) then
        RaiseException('Не удалось перенастроить службу помощника "' + ServiceName +
          '" (код ' + IntToStr(ResultCode) + '). Установка прервана.');
    end
    else
    begin
      // FOREIGN service with the same name whose binary is OUTSIDE {app}. We
      // will not overwrite or delete a service we do not own. Abort with an
      // actionable message; under /VERYSILENT this exits nonzero.
      RaiseException('Обнаружена сторонняя служба "' + ServiceName +
        '", не принадлежащая этой программе (путь вне папки установки). ' +
        'Удалите её вручную и повторите установку — установка прервана, ' +
        'чтобы не повредить чужую службу.');
    end;
  end
  else
  begin
    // Absent (fresh install): create it.
    if not Exec('sc.exe', 'create "' + ServiceName + '" ' + BinPathArg + ' start= auto', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) or (ResultCode <> 0) then
      RaiseException('Не удалось создать службу помощника "' + ServiceName +
        '" (код ' + IntToStr(ResultCode) + '). Установка прервана.');
  end;

  // Start and wait for RUNNING (bounded ~15s for slow disks / AV scanning).
  // NOT reaching RUNNING here is NOT fatal: the service IS registered with
  // start=auto, so AV/slow-disk latency (or a pending reboot) may simply delay
  // the first start — it will come up on the next boot / app launch. Failing a
  // fully-registered install over a slow start would be a false negative, so we
  // LOG a warning and continue. (Missing binary / foreign service / sc
  // create/config failures above are the real, fatal errors and DO raise.)
  Exec('sc.exe', 'start "' + ServiceName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  for i := 0 to 29 do
  begin
    if ServiceIsRunning(ServiceName) then
      Break;
    Sleep(500);
  end;
  if not ServiceIsRunning(ServiceName) then
    Log('WARNING: DropwebHelperService is registered (auto-start) but did not ' +
      'reach RUNNING within 15s; it should start on next boot / app launch.');

  // SCM RUNNING only proves the service process started, not that its HTTP
  // endpoint is bound. Wait for the same token-verified /ping used by the app.
  // Timeout is deliberately non-fatal: Wave 1B's app watchdog is authoritative.
  WaitForVerifiedHelperPing;
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
  // Path BOUNDARY "{app}\" (AddBackslash) — see ServiceBelongsToApp: prevents a
  // foreign "…\dropweb2\…" Run command from matching our "…\dropweb" dir.
  AppDir := AddBackslash(ExpandConstant('{app}'));
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
  // Path BOUNDARY "{app}\" (AddBackslash) — see ServiceBelongsToApp: prevents a
  // foreign "…\dropweb2\…" scheduled-task action from matching "…\dropweb".
  AppDir := AddBackslash(ExpandConstant('{app}'));
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
begin
  // Detection only — NOTHING destructive here. {app} is not yet resolved for a
  // fresh install, so we must not stop services or close processes before we
  // can prove ownership. All process/service handling is deferred to ssInstall
  // (ownership-gated stop + Restart Manager) and ssPostInstall
  // (EnsureHelperService).
  IsUpgrade := IsAppInstalled();
  if IsUpgrade then
    PreviousVersion := GetInstalledVersion();
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
begin
  if CurStep = ssInstall then
  begin
    // CLEAN INSTALL (Tier 1): runs before [InstallDelete] wipes {app} and
    // before [Files] copies fresh binaries ({app} is resolved by now).
    //
    // Stop OUR helper service so its .exe unlocks for the wipe — but ONLY if it
    // is ours (binPath inside {app}). A foreign same-name service is left
    // untouched here; EnsureHelperService (ssPostInstall) will abort on it.
    // Our own running app/core are closed by Restart Manager (CloseApplications),
    // which is scoped to files under {app} — no name-based kill.
    if ServiceBelongsToApp('DropwebHelperService') then
    begin
      Exec('sc.exe', 'stop "DropwebHelperService"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(500);
    end;
    // Drop stale services / autostart from older or pre-rebrand builds that
    // live inside our install dir (a separate FlClashX elsewhere is untouched).
    CleanLineageLeftovers;
  end;

  if CurStep = ssPostInstall then
  begin
    // Refresh icon cache/associations only. The helper-service lifecycle is
    // NOT done here: exceptions raised in ssPostInstall are handled
    // non-fatally by Inno (SetStep(ssPostInstall, True)) and would NOT fail
    // Setup / return a nonzero exit. Service create/config validation runs in
    // the [Files] AfterInstall hook (EnsureHelperService), which sits inside
    // PerformInstall and gives a fatal exit code 4 on failure.
    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, 0, 0);
    Sleep(500);
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
begin
  case CurUninstallStep of
     usUninstall:
     begin
      // NO name-based kill. Our own running app/core are closed by Restart
      // Manager (CloseApplications, scoped to files under {app}); a foreign
      // same-name process elsewhere is never touched.
      //
      // Stop + delete the helper service ONLY if it is OURS (binPath inside
      // {app}). If a foreign service of the same name exists (path mismatch)
      // it is left completely untouched — RemoveServiceIfOurs gates on
      // ServiceBelongsToApp('DropwebHelperService').
      RemoveServiceIfOurs('DropwebHelperService');
      Sleep(300);
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
; Copy everything EXCEPT the helper first. The helper is installed LAST (below)
; with AfterInstall so EnsureHelperService runs while all other program files
; are already on disk.
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Excludes: "DropwebHelperService.exe"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files
; Helper LAST + AfterInstall: EnsureHelperService runs INSIDE PerformInstall
; (the fatal install transaction). An exception it raises there aborts Setup
; with exit code 4 — unlike ssPostInstall, whose exceptions Inno swallows
; (SetStep(ssPostInstall, True)) and would let a broken helper "succeed".
Source: "{{SOURCE_DIR}}\\DropwebHelperService.exe"; DestDir: "{app}"; Flags: ignoreversion; AfterInstall: EnsureHelperService

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon
[Run]
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: {% if PRIVILEGES_REQUIRED == 'admin' %}runascurrentuser{% endif %} nowait postinstall skipifsilent
