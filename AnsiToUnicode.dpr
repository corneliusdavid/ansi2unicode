program AnsiToUnicode;

uses
  Forms,
  ufrmAnsiToUnicodeMain in 'ufrmAnsiToUnicodeMain.pas' {frmAnsiToUnicode};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'ANSI to Unicode';
  Application.CreateForm(TfrmAnsiToUnicode, frmAnsiToUnicode);
  Application.Run;
end.
