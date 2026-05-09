unit LinuxLibStdCxx;
// Pre-loads libstdc++ with RTLD_GLOBAL so its symbols (__cxa_pure_virtual etc.)
// are visible when System.Skia later dlopen's libsk4d.so.

interface

implementation

{$IFDEF LINUX}
uses
  Posix.Dlfcn;

initialization
  dlopen('libstdc++.so.6', RTLD_NOW or RTLD_GLOBAL);
{$ENDIF}

end.
