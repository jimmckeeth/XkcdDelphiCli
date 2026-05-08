unit testItermApi;

interface
uses DUnitX.TestFramework;

type
  [TestFixture]
  TTestItermApi = class
  public
    [Test] procedure EncodeHasCorrectOSCPrefix;
    [Test] procedure EncodeEndsWithBEL;
    [Test] procedure EncodeBase64RoundTrip;
    [Test] procedure EncodeContainsInlineFlag;
  end;

implementation
uses itermapi, System.NetEncoding, System.SysUtils;

const
  CSamplePngB64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQI12NgAAAAAgAB4iG8MwAAAABJRU5ErkJggg==';

function MakeSamplePng: TBytes;
begin
  Result := TNetEncoding.Base64.DecodeStringToBytes(CSamplePngB64);
end;

const
  CExpectedPrefix = #$1B + ']1337;File=inline=1;width=auto:';

procedure TTestItermApi.EncodeHasCorrectOSCPrefix;
var LResult: string;
begin
  LResult := EncodeImageAsITerm(MakeSamplePng);
  Assert.IsTrue(LResult.StartsWith(CExpectedPrefix), 'Must start with OSC 1337 File prefix');
end;

procedure TTestItermApi.EncodeEndsWithBEL;
var LResult: string;
begin
  LResult := EncodeImageAsITerm(MakeSamplePng);
  Assert.IsTrue(LResult.EndsWith(#7), 'Must end with BEL (#7)');
end;

procedure TTestItermApi.EncodeBase64RoundTrip;
var LData, LDecoded: TBytes; LResult, LB64: string;
begin
  LData   := MakeSamplePng;
  LResult := EncodeImageAsITerm(LData);
  LB64    := LResult.Substring(Length(CExpectedPrefix), LResult.Length - Length(CExpectedPrefix) - 1);
  LDecoded := TNetEncoding.Base64.DecodeStringToBytes(LB64);
  Assert.AreEqual(Length(LData), Length(LDecoded), 'Decoded length must match');
  for var I := 0 to High(LData) do
    Assert.AreEqual(LData[I], LDecoded[I], Format('Byte %d must match', [I]));
end;

procedure TTestItermApi.EncodeContainsInlineFlag;
var LResult: string;
begin
  LResult := EncodeImageAsITerm(MakeSamplePng);
  Assert.IsTrue(LResult.Contains('inline=1'), 'Must specify inline=1');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestItermApi);

end.
