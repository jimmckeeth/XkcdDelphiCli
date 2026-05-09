unit termimageapi;

interface

uses termdetectapi;

procedure DisplayImage(const AFileName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer = 800; AInvert: Boolean = False);

procedure AutoDisplayImage(const AFileName: string; AMaxWidth: Integer = 800;
  AInvert: Boolean = False);

implementation

uses
  System.SysUtils,
  sixelapi,
  kittieapi,
  itermapi
  {$IFDEF MSWINDOWS}
  , Winapi.ShellAPI, Winapi.Windows
  {$ELSE}
  , Posix.Stdlib
  {$ENDIF}
  ;

procedure OpenWithOsViewer(const AFileName: string);
begin
  {$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(AFileName), nil, nil, SW_SHOWNORMAL);
  {$ELSE}
  _system(PAnsiChar(AnsiString('xdg-open "' + AFileName + '"')));
  {$ENDIF}
end;

procedure DisplayImage(const AFileName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer; AInvert: Boolean);
begin
  case AProtocol of
    tpKittyPlus, tpKitty: DisplayImageAsKitty(AFileName, AMaxWidth, AInvert);
    tpITerm:              DisplayImageAsITerm(AFileName, AMaxWidth, AInvert);
    tpSixel:              DisplayImageAsSixel(AFileName, AMaxWidth, AInvert);
    tpNone:               OpenWithOsViewer(AFileName);
  end;
end;

procedure AutoDisplayImage(const AFileName: string; AMaxWidth: Integer;
  AInvert: Boolean);
begin
  DisplayImage(AFileName, DetectProtocol, AMaxWidth, AInvert);
end;

end.
