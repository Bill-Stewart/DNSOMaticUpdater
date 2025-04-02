; DNSOMaticUpdater.iss
; Written by Bill Stewart (bstewart AT iname.com)

#if Ver < EncodeVer(6,3,3,0)
#error This script requires Inno Setup 6.3.3 or later
#endif

#define AppID "{47DA5A3E-3DCB-4B8F-A2A5-3133AB9F3ABC}"
#define AppName "DNS-O-Matic Updater"
#define AppShortName "DNSOMaticUpdater"
#define AppVersion "0.0.2"
#define AppPublisher "Bill Stewart"
#define AppURL "https://github.com/Bill-Stewart/DNSOMaticUpdater/"
#define ScriptName AppShortName + ".ps1"
#define LogFileName AppShortName + ".log"
#define IconFileName AppShortName + ".ico"
#define LastIPFileName = "LastIP.txt"
#define ScheduledTaskName "DNS-O-Matic\" + AppName
#define NetworkProfileFileName "NetworkProfile.txt"
#define CredentialFileName "Credentials.dat"
#define LicenseFileName "License.rtf"

[Setup]
AppId={{#AppID}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
MinVersion=10
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=no
CloseApplicationsFilter=*.exe
RestartApplications=yes
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableWelcomePage=yes
DisableProgramGroupPage=no
AlwaysShowGroupOnReadyPage=yes
AllowNoIcons=yes
PrivilegesRequired=admin
OutputDir=.
OutputBaseFilename={#AppShortName}-Setup
Compression=lzma2/max
SolidCompression=yes
UsePreviousTasks=yes
WizardStyle=modern
WizardSizePercent=120
UninstallFilesDir={app}\uninstall
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#IconFileName}
VersionInfoProductName={#AppName}
VersionInfoCompany={#AppPublisher}
VersionInfoVersion={#AppVersion}

[Messages]
SetupWindowTitle={#AppName} Setup

[Languages]
Name: en; MessagesFile: "compiler:Default.isl,Messages-en.isl"; InfoBeforeFile: "README-en.rtf"

[Dirs]
Name: {app}; Permissions: service-modify users-modify

[Files]
Source: "License.rtf"; flags: dontcopy
; startps.exe - https://github.com/Bill-Stewart/startps/
Source: "i386\startps.exe"; DestDir: {app}; Check: not IsX64Compatible()
Source: "x86_64\startps.exe"; DestDir: {app}; Check: IsX64Compatible()
Source: "{#ScriptName}"; DestDir: {app}
Source: "{#IconFileName}"; DestDir: {app}

[Icons]
Name: "{group}\{cm:IconsSelectNetworkProfileName}"; \
  Comment: {cm:IconsSelectNetworkProfileComment}; \
  Filename: "{app}\startps.exe"; \
  Parameters: "-e -p -t ""{cm:IconsSelectNetworkProfileName}"" ""{app}\{#ScriptName}"" -- -SelectNetworkProfile"; \
  Flags: excludefromshowinnewinstall
Name: "{group}\{cm:IconsUpdateCredentialsName}"; \
  Comment: {cm:IconsUpdateCredentialsComment}; \
  Filename: "{app}\startps.exe"; \
  Parameters: "-p -t ""{cm:IconsUpdateCredentialsName}"" ""{app}\{#ScriptName}"" -- -SetCredentials"; \
  Flags: excludefromshowinnewinstall
Name: "{group}\{cm:IconsUpdate}"; \
  Comment: {cm:IconsUpdateComment}; \
  Filename: "{app}\startps.exe"; \
  Parameters: "-p -t ""{cm:IconsUpdate}"" ""{app}\{#ScriptName}"" -- -Update"; \
  Flags: excludefromshowinnewinstall

[Tasks]
Name: updatenetworkprofile; \
  Description: {cm:TasksUpdateNetworkProfile}; \
  Flags: checkedonce unchecked; \
  Check: (not WizardSilent()) and (NetworkProfileExists() or CredentialExists())
Name: updatecredentials; \
  Description: {cm:TasksUpdateCredentials}; \
  Flags: checkedonce unchecked; \
  Check: (not WizardSilent()) and (NetworkProfileExists() or CredentialExists())
Name: scheduledtask; \
  Description: {cm:TasksUseScheduledTask}

[Run]
Filename: "{app}\startps.exe"; \
  Parameters: "-p -t ""{cm:IconsUpdate}"" ""{app}\{#ScriptName}"" -- -Update"; \
  Description: {cm:RunUpdateDescription}; \
  Flags: nowait postinstall; \
  Check: NetworkProfileExists() and CredentialExists()

[Code]
var
  OutputMsgMemoPage: TOutputMsgMemoWizardPage;
  ConfigFileNames: TArrayOfString;
  ApplicationUninstalled: Boolean;

function AnyConfigFilesExist(): Boolean;
var
  I: Integer;
begin
  result := false;
  if GetArrayLength(ConfigFileNames) = 0 then
  begin
    SetArrayLength(ConfigFileNames, 4);
    ConfigFileNames[0] := ExpandConstant('{app}\{#CredentialFileName}');
    ConfigFileNames[1] := ExpandConstant('{app}\{#NetworkProfileFileName}');
    ConfigFileNames[2] := ExpandConstant('{app}\{#LastIPFileName}');
    ConfigFileNames[3] := ExpandConstant('{app}\{#LogFileName}');
  end;
  for I := 0 to GetArrayLength(ConfigFileNames) - 1 do
  begin
    result := FileExists(ConfigFileNames[I]);
    if result then
      break;
  end;
end;

function NetworkProfileExists(): Boolean;
begin
  result := FileExists(ExpandConstant('{app}\{#NetworkProfileFileName}'));
end;

function CredentialExists(): Boolean;
begin
  result := FileExists(ExpandConstant('{app}\{#CredentialFileName}'));
end;

function InitializeSetup(): Boolean;
begin
  result := true;
  SetArrayLength(ConfigFileNames, 0);
end;

procedure InitializeWizard();
var
  LicenseFileText: AnsiString;
begin
  ExtractTemporaryFile('{#LicenseFileName}');
  if LoadStringFromFile(ExpandConstant('{tmp}\{#LicenseFileName}'), LicenseFileText) then
  begin
    OutputMsgMemoPage := CreateOutputMsgMemoPage(wpWelcome,
      CustomMessage('MemoPageCaption'),
      CustomMessage('MemoPageDescription'),
      CustomMessage('MemoPageSubCaption'),
      LicenseFileText);
  end;
  // No Start menu icons is the default
  WizardForm.NoIconsCheck.Checked := true;
end;

function ExecEx(const FileName, Params: string; const Hide: Boolean): Integer;
var
  Success: Boolean;
  ShowCmd: Integer;
begin
  Log(Format('ExecEx: "%s" %s', [FileName, Params]));
  if Hide then
    ShowCmd := SW_HIDE
  else
    ShowCmd := SW_SHOWNORMAL;
  Success := Exec(FileName,  // Filename
    Params,                  // Params
    '',                      // WorkingDir
    ShowCmd,                 // ShowCmd
    ewWaitUntilTerminated,   // TExecWait
    result);                 // ResultCode
  if Success then
    Log(Format('ExecEx exit code: %s', [IntToStr(result)]))
  else
    Log(Format('ExecEx failed: %s (%s)', [SysErrorMessage(result), IntToStr(result)]));
end;

function ScheduledTaskExists(): Boolean;
var
  ResultCode: Integer;
begin
  ResultCode := ExecEx(ExpandConstant('{sys}\schtasks.exe'),
    '/Query /TN "{#ScheduledTaskName}"',
    true);
  result := ResultCode = 0;
end;

procedure CreateScheduledTask();
begin
  // S-1-5-19 = local service
  ExecEx(ExpandConstant('{sys}\schtasks.exe'),
    ExpandConstant('/Create'
      + ' /RU S-1-5-19'
      + ' /SC MINUTE'
      + ' /MO 5'
      + ' /TN "{#ScheduledTaskName}"'
      + ' /TR "\"{app}\startps.exe\" -n \"{app}\{#ScriptName}\" -- -Update -Log"'
      + ' /F'),
    true);
end;

procedure DeleteScheduledTask();
begin
  ExecEx(ExpandConstant('{sys}\schtasks.exe'),
    '/Delete /TN "{#ScheduledTaskName}" /F',
    true);
end;

procedure SetExecutablePermissions();
var
  FileNames: TArrayOfString;
  I: Integer;
begin
  SetArrayLength(FileNames, 3);
  FileNames[0] := ExpandConstant('{app}\{#ScriptName}');
  FileNames[1] := ExpandConstant('{app}\startps.exe');
  FileNames[2] := ExpandConstant('{uninstallexe}');
  // S-1-5-19 - Builtin 'NT AUTHORITY\LocalService' account
  // S-1-5-32-545 - Local Users group
  for I := 0 to GetArrayLength(FileNames) - 1 do
  begin
    // Disable inheritance and propagate ACEs (must be done separately)
    ExecEx(ExpandConstant('{sys}\icacls.exe'),
      '"' + FileNames[I] + '" /inheritance:d',
      true);
    // Update ACEs for LocalService and Users (remove, then grant)
    ExecEx(ExpandConstant('{sys}\icacls.exe'),
      '"' + FileNames[I] + '" /remove *S-1-5-19 /grant *S-1-5-19:RX /remove *S-1-5-32-545 /grant *S-1-5-32-545:RX',
      true);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    SetExecutablePermissions();
    if not WizardSilent() then
    begin
      if ((not NetworkProfileExists()) and (not CredentialExists())) or
        (WizardIsTaskSelected('updatenetworkprofile') and WizardIsTaskSelected('updatecredentials')) then
      begin
        ExecEx(ExpandConstant('{app}\startps.exe'),
          ExpandConstant('-w -t "{cm:FirstRunSetupScriptTitle}" "{app}\{#ScriptName}" -- -Setup'),
          false);
      end
      else
      begin
        if WizardIsTaskSelected('updatenetworkprofile') then
        begin
          ExecEx(ExpandConstant('{app}\startps.exe'),
            ExpandConstant('-w -t "{cm:IconsSelectNetworkProfileName}" "{app}\{#ScriptName}" -- -SelectNetworkProfile'),
            false);
        end
        else if WizardIsTaskSelected('updatecredentials') then
        begin
          ExecEx(ExpandConstant('{app}\startps.exe'),
            ExpandConstant('-w -t "{cm:IconsUpdateCredentialsName}" "{app}\{#ScriptName}" -- -SetCredentials'),
            false);
        end;
      end;
    end;
    if WizardIsTaskSelected('scheduledtask') then
    begin
      if not ScheduledTaskExists() then
        CreateScheduledTask();
    end
    else
    begin
      if ScheduledTaskExists() then
        DeleteScheduledTask();
    end;
  end;
end;

procedure DeleteFileEx(const FileName: string);
begin
  if DeleteFile(FileName) then
    Log(FmtMessage(CustomMessage('FileDeleteSucceeded'), [FileName]))
  else
    Log(FmtMessage(CustomMessage('FileDeleteFailed'), [FileName]))
end;

procedure DeleteConfigurationFiles();
var
  I: Integer;
begin
  for I := 0 to GetArrayLength(ConfigFileNames) - 1 do
  begin
    if FileExists(ConfigFileNames[I]) then
      DeleteFileEx(ConfigFileNames[I]);
  end;
end;

function InitializeUninstall(): Boolean;
begin
  result := true;
  SetArrayLength(ConfigFileNames, 0);
  ApplicationUninstalled := false;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    if (not UninstallSilent()) and AnyConfigFilesExist() then
    begin
      if MsgBox(CustomMessage('UninstallRemoveConfigurationFiles'), mbConfirmation, MB_YESNO) = IDYES then
        DeleteConfigurationFiles();
    end;
    if ScheduledTaskExists() then
      DeleteScheduledTask();
    ApplicationUninstalled := true;
  end;
end;

procedure DeInitializeUninstall();
begin
  if ApplicationUninstalled then
    RemoveDir(ExpandConstant('{app}'));
end;
