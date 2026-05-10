// Copyright © 2026 by James McKeeth - Licensed GPL 3.0
// https://github.com/jimmckeeth/XkcdDelphiCli
unit testKittieApi;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestKittieApi = class
  public
    [Test]
    procedure EncodeSmallImageSingleChunk;
    [Test]
    procedure EncodeSmallImageHasCorrectDelimiters;
    [Test]
    procedure EncodeSmallImageHasTransmitAction;
    [Test]
    procedure EncodeLargeImageProducesMultipleChunks;
    [Test]
    procedure EncodeLargeImageLastChunkHasM0;
    [Test]
    procedure EncodeRoundtripVerifiesBase64Content;
  end;

implementation

uses kittieapi, System.NetEncoding, System.SysUtils, System.Math, System.StrUtils;

const
  CSamplePngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJggg==';

function MakeSamplePng: TBytes;
begin
  Result := TNetEncoding.Base64.DecodeStringToBytes(CSamplePngB64);
end;

function CountOccurrences(const AStr, ASub: string): Integer;
var
  LPos: Integer;
begin
  Result := 0;
  LPos := 1;
  while True do
  begin
    LPos := PosEx(ASub, AStr, LPos);
    if LPos = 0 then Break;
    Inc(Result);
    Inc(LPos, Length(ASub));
  end;
end;

procedure TTestKittieApi.EncodeSmallImageSingleChunk;
var
  LResult: string;
begin
  LResult := EncodeImageAsKitty(MakeSamplePng);
  Assert.AreEqual(1, CountOccurrences(LResult, #$1B + '_G'));
end;

procedure TTestKittieApi.EncodeSmallImageHasCorrectDelimiters;
var
  LResult: string;
begin
  LResult := EncodeImageAsKitty(MakeSamplePng);
  Assert.IsTrue(LResult.StartsWith(#$1B + '_G'), 'Must start with APC');
  Assert.IsTrue(LResult.EndsWith(#$1B + '\'), 'Must end with ST');
end;

procedure TTestKittieApi.EncodeSmallImageHasTransmitAction;
var
  LResult: string;
begin
  LResult := EncodeImageAsKitty(MakeSamplePng);
  Assert.IsTrue(LResult.Contains('a=T'), 'Must have transmit action');
  Assert.IsTrue(LResult.Contains('f=100'), 'Must specify PNG format (100)');
  Assert.IsTrue(LResult.Contains('m=0'), 'Single chunk must have m=0');
end;

procedure TTestKittieApi.EncodeLargeImageProducesMultipleChunks;
var
  LData: TBytes;
  LResult: string;
begin
  SetLength(LData, 3500);
  FillChar(LData[0], 3500, $AA);
  LResult := EncodeImageAsKitty(LData);
  Assert.IsTrue(CountOccurrences(LResult, #$1B + '_G') >= 2,
    'Large image should produce multiple APC frames');
end;

procedure TTestKittieApi.EncodeLargeImageLastChunkHasM0;
var
  LData: TBytes;
  LResult: string;
  LLastFrame: string;
  LLastPos: Integer;
begin
  SetLength(LData, 3500);
  FillChar(LData[0], 3500, $AA);
  LResult := EncodeImageAsKitty(LData);
  LLastPos := LResult.LastIndexOf(#$1B + '_G');
  Assert.IsTrue(LLastPos >= 0, 'Should have at least one APC frame');
  LLastFrame := LResult.Substring(LLastPos);
  Assert.IsTrue(LLastFrame.Contains('m=0'), 'Last frame must have m=0');
  Assert.IsTrue(LResult.Contains('m=1'), 'Multi-chunk should have m=1 frames');
end;

procedure TTestKittieApi.EncodeRoundtripVerifiesBase64Content;
var
  LData: TBytes;
  LResult, LBase64Part: string;
  LDecoded: TBytes;
  LSemiPos, LEndPos: Integer;
begin
  LData := MakeSamplePng;
  LResult := EncodeImageAsKitty(LData);
  LSemiPos := Pos(';', LResult);
  LEndPos  := Pos(#$1B + '\', LResult);
  Assert.IsTrue((LSemiPos > 0) and (LEndPos > LSemiPos), 'Frame structure invalid');
  LBase64Part := LResult.Substring(LSemiPos, LEndPos - LSemiPos - 1);
  LDecoded := TNetEncoding.Base64.DecodeStringToBytes(LBase64Part);
  Assert.AreEqual(Length(LData), Length(LDecoded), 'Decoded byte count must match');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestKittieApi);

end.
