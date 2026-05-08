unit termimageapi;

interface

uses termdetectapi;

procedure DisplayImage(const AFileName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer = 800);

procedure AutoDisplayImage(const AFileName: string; AMaxWidth: Integer = 800);

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
  Posix.Stdlib.system(PAnsiChar(AnsiString('xdg-open "' + AFileName + '"')));
  {$ENDIF}
end;

procedure DisplayImage(const AFileName: string;
  AProtocol: TTerminalProtocol; AMaxWidth: Integer);
begin
  case AProtocol of
    tpKittyPlus, tpKitty: DisplayImageAsKitty(AFileName, AMaxWidth);
    tpITerm:              DisplayImageAsITerm(AFileName, AMaxWidth);
    tpSixel:              DisplayImageAsSixel(AFileName, AMaxWidth);
    tpNone:               OpenWithOsViewer(AFileName);
  end;
end;

procedure AutoDisplayImage(const AFileName: string; AMaxWidth: Integer);
begin
  DisplayImage(AFileName, DetectProtocol, AMaxWidth);
end;

end.
