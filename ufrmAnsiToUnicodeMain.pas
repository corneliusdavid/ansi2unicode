unit ufrmAnsiToUnicodeMain;
(*
 * by: David E. Cornelius
 * of: Cornelius Concepts
 * on: Feburary, 2010
 * in: Delphi 2009
 * to: convert a whole folder of Windows ANSI files to Unicode
 *)

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ExtCtrls, ActnList, StdActns, ImgList, CheckLst, ComCtrls;

type
  TfrmAnsiToUnicode = class(TForm)
    pnlConfig: TPanel;
    edtSourcePath: TButtonedEdit;
    Label1: TLabel;
    Label2: TLabel;
    edtDestinationPath: TButtonedEdit;
    imlBtnEdit: TImageList;
    aclMain: TActionList;
    imlActions: TImageList;
    actSelectSourceFolder: TBrowseForFolder;
    actSelectDestFolder: TBrowseForFolder;
    btnStop: TButton;
    btnStart: TButton;
    actConvertStart: TAction;
    actConvertStop: TAction;
    edtAnsiExt: TLabeledEdit;
    edtUniExt: TLabeledEdit;
    pnlFiles: TGridPanel;
    cbOverwrite: TCheckBox;
    clbSource: TCheckListBox;
    lbDest: TListBox;
    BalloonHint: TBalloonHint;
    cbStripBOM: TCheckBox;
    StatusBar: TStatusBar;
    InfoSpeedButton: TSpeedButton;
    procedure edtSourcePathClick(Sender: TObject);
    procedure actConvertStartExecute(Sender: TObject);
    procedure actConvertStopExecute(Sender: TObject);
    procedure edtDestinationPathClick(Sender: TObject);
    procedure edtExtExit(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure InfoSpeedButtonClick(Sender: TObject);
  private
    const
      INIKEY_SavedSettings = 'SavedSettings';
      INIVAL_SourcePath = 'SourcePath';
      INIVAL_DestPath = 'DestinationPath';
      INIVAL_SourceExt = 'SourceExtension';
      INIVAL_DestExt = 'DestinationExtension';
      INIVAL_OverwriteDest = 'OverwriteDestination';
      INIVal_StripBOM = 'StripByteOrderMark';
      INIKEY_Layout = 'Layout';
      INIVAL_ScreenTop = 'ScreenTop';
      INIVAL_ScreenLeft = 'ScreenLeft';
      INIVAL_ScreenWidth = 'ScreenWidth';
      INIVAL_ScreenHeight = 'ScreenHeight';
    type
      TNoPreambleUnicode = class(TUnicodeEncoding)
      public
        function GetPreamble: TBytes; override;
      end;
    var
      FCanceled: Boolean;
    function  BuildIniFilename: string;
    procedure PutInfoButtonOnStatusBar;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure ListFiles;
    procedure ConvertFiles;
    procedure SetEditsAndCancel(AEnable: Boolean);
  end;

var
  frmAnsiToUnicode: TfrmAnsiToUnicode;

implementation

{$R *.dfm}

uses
  IniFiles;


procedure TfrmAnsiToUnicode.actConvertStartExecute(Sender: TObject);
begin
  FCanceled := False;

  SetEditsAndCancel(False);
  try
    ListFiles;
    if (not FCanceled) and (clbSource.Items.Count > 0) then
      ConvertFiles
    else
      MessageBox(Handle, PChar('No files found to convert.'),
                         PChar(Application.Title),
                         MB_OK + MB_ICONASTERISK + MB_TASKMODAL);
  finally
    SetEditsAndCancel(True);
  end;
end;

procedure TfrmAnsiToUnicode.actConvertStopExecute(Sender: TObject);
begin
  FCanceled := True;
end;

procedure TfrmAnsiToUnicode.ConvertFiles;
var
  i: Integer;
  sl: TStringList;
  src_path: string;
  dest_path: string;

  // this is the key part in the unicode conversion
  uni: TUnicodeEncoding;
begin
  Screen.Cursor := crAppStart;
  try
    lbDest.Clear;

    // save these settings in local variables for readability and speed
    src_path := IncludeTrailingPathDelimiter(edtSourcePath.Text);
    dest_path := IncludeTrailingPathDelimiter(edtDestinationPath.Text);

    if cbStripBOM.Checked then
      uni := TNoPreambleUnicode.Create
    else
      uni := TUnicodeEncoding.Create;

    try
      // use a string list for ease of dealing with text files and converting
      sl := TStringList.Create;
      try
        for i := 0 to clbSource.Items.Count - 1 do begin
          // list the file that will be converted in the destination listbox
          lbDest.Items.Add(clbSource.Items[i]);
          // update the screen to show the next file being processed
          lbDest.Update;

          // read in the file
          sl.LoadFromFile(src_path + clbSource.Items[i]);
          // save it out to the destination path with the new encoding
          sl.SaveToFile(ChangeFileExt(dest_path + clbSource.Items[i], edtUniExt.Text), uni);

          // check it off in the source list
          clbSource.Checked[i] := True;

          // clear the string list for the next file
          sl.Clear;

          // allow window messages to process
          Application.ProcessMessages;
          // was the Abort button clicked?
          if FCanceled then
            Break;
        end;
      finally
        uni.Free;
      end;
    finally
      sl.Free;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

function TfrmAnsiToUnicode.BuildIniFilename: string;
var
  SettingsFolder: string;
begin
  // settings are in the standard user folder
  SettingsFolder := GetEnvironmentVariable('APPDATA');
  Result := IncludeTrailingPathDelimiter(SettingsFolder) +
               ChangeFileExt(ExtractFileName(Application.ExeName), '.ini');
end;

procedure TfrmAnsiToUnicode.edtExtExit(Sender: TObject);
var
  edt: TLabeledEdit;
begin
  edt := (Sender as TLabeledEdit);
  if Pos('.', edt.Text) = 0 then
    edt.Text := '.' + edt.Text;
end;

procedure TfrmAnsiToUnicode.edtDestinationPathClick(Sender: TObject);
// call a standard Browse Folder action to select the destination path
begin
  actSelectDestFolder.RootDir := edtDestinationPath.Text;
  if actSelectDestFolder.Execute then
    edtDestinationPath.Text := actSelectDestFolder.Folder;
end;

procedure TfrmAnsiToUnicode.ListFiles;
// list all the files from the source folder that will be converted
var
  found: Boolean;
  sr: TSearchRec;
begin
  Screen.Cursor := crHourGlass;
  try
    clbSource.Clear;

    found := FindFirst(IncludeTrailingPathDelimiter(edtSourcePath.Text) +
                             '*' + edtAnsiExt.Text, faAnyFile, sr) = 0;
    while found and (not FCanceled) do begin
      clbSource.Items.Add(sr.Name);
      clbSource.Update;

      Application.ProcessMessages;

      found := FindNext(sr) = 0;
    end;
    FindClose(sr);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmAnsiToUnicode.LoadSettings;
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(BuildIniFilename);
  try
    // restore screen layout, default is current dimensions
    Top := ini.ReadInteger(INIKEY_Layout, INIVAL_ScreenTop, Top);
    Left := ini.ReadInteger(INIKEY_Layout, INIVAL_ScreenLeft, Left);
    Width := ini.ReadInteger(INIKEY_Layout, INIVAL_ScreenWidth, Width);
    Height := ini.ReadInteger(INIKEY_Layout, INIVAL_ScreenHeight, Height);

    // restore last used settings
    edtSourcePath.Text :=      ini.ReadString(INIKEY_SavedSettings, INIVAL_SourcePath, EmptyStr);
    edtDestinationPath.Text := ini.ReadString(INIKEY_SavedSettings, INIVAL_DestPath, EmptyStr);
    edtAnsiExt.Text :=         ini.ReadString(INIKEY_SavedSettings, INIVAL_SourceExt, EmptyStr);
    edtUniExt.Text :=          ini.ReadString(INIKEY_SavedSettings, INIVAL_DestExt, EmptyStr);
    cbOverwrite.Checked :=     ini.ReadBool(INIKEY_SavedSettings, INIVAL_OverwriteDest, True);
    cbStripBOM.Checked :=      ini.ReadBool(INIKEY_SavedSettings, INIVal_StripBOM, False);
  finally
    ini.Free;
  end;
end;

procedure TfrmAnsiToUnicode.PutInfoButtonOnStatusBar;
begin
  InfoSpeedButton.Parent := StatusBar;
  InfoSpeedButton.Top := 1;
  InfoSpeedButton.Left := 1;
end;

procedure TfrmAnsiToUnicode.SaveSettings;
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(BuildIniFilename);
  try
    // save current screen layout
    ini.WriteInteger(INIKEY_Layout, INIVAL_ScreenTop, Top);
    ini.WriteInteger(INIKEY_Layout, INIVAL_ScreenLeft, Left);
    ini.WriteInteger(INIKEY_Layout, INIVAL_ScreenWidth, Width);
    ini.WriteInteger(INIKEY_Layout, INIVAL_ScreenHeight, Height);

    // save settings for convenience in case of reuse next time
    ini.WriteString(INIKEY_SavedSettings, INIVAL_SourcePath, edtSourcePath.Text);
    ini.WriteString(INIKEY_SavedSettings, INIVAL_DestPath, edtDestinationPath.Text);
    ini.WriteString(INIKEY_SavedSettings, INIVAL_SourceExt, edtAnsiExt.Text);
    ini.WriteString(INIKEY_SavedSettings, INIVAL_DestExt, edtUniExt.Text);
    ini.WriteBool(INIKEY_SavedSettings, INIVAL_OverwriteDest, cbOverwrite.Checked);
    ini.WriteBool(INIKEY_SavedSettings, INIVal_StripBOM, cbStripBOM.Checked);
  finally
    ini.Free;
  end;
end;

procedure TfrmAnsiToUnicode.SetEditsAndCancel(AEnable: Boolean);
var
  i: Integer;
begin
  for i := 0 to pnlConfig.ControlCount - 1 do
    if pnlConfig.Controls[i].Tag = 1 then
      pnlConfig.Controls[i].Enabled := AEnable
    else if pnlConfig.Controls[i].Tag = 2 then
      pnlConfig.Controls[i].Enabled := not AEnable;

  Application.ProcessMessages;
end;

procedure TfrmAnsiToUnicode.edtSourcePathClick(Sender: TObject);
// call a standard Browse Folder action to select the source path
begin
  actSelectSourceFolder.RootDir := edtSourcePath.Text;
  if actSelectSourceFolder.Execute then
    edtSourcePath.Text := actSelectSourceFolder.Folder;
end;

procedure TfrmAnsiToUnicode.FormActivate(Sender: TObject);
begin
  LoadSettings;
  PutInfoButtonOnStatusBar;
end;

procedure TfrmAnsiToUnicode.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveSettings;
  Action := caFree;
end;

procedure TfrmAnsiToUnicode.InfoSpeedButtonClick(Sender: TObject);
const
  InfoText = 'This program converts standard Windows text files from ANSI encoding (standard 1252 code page) to Unicode encoding. ' +
             'There are many Unicode formats, but this one assumes you just want to do what Notepad would do if you select "Unicode" ' +
             'during a Save As.  This turns out to be a UTF-16 "little endian" format, the most common. ' +
             'There are no command-line paramters and no separate documentation.'#13#13#10 +
             'Written by David E. Cornelius of Cornelius Concepts, February, 2010.';
begin
  MessageBox(Handle, PChar(InfoText), PChar(Application.Title),
             MB_OK + MB_ICONINFORMATION + MB_APPLMODAL);
end;

{ TfrmAnsiToUnicode.TNoPreambleUnicode }

function TfrmAnsiToUnicode.TNoPreambleUnicode.GetPreamble: TBytes;
begin
  SetLength(Result, 0);
end;

end.
