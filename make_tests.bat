REM @echo off
curl -O https://raw.githubusercontent.com/vlang/vc/master/v.c
gcc -std=gnu11 -DUNICODE -D_UNICODE -w -o vc.exe v.c
del v.c

"%ProgramFiles(x86)%\\Microsoft Visual Studio\\Installer\\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath

vc.exe -o v.exe compiler
vc.exe -os msvc -o v.msvc.exe compiler
v.msvc.exe -os msvc -o v.msvc.2.exe compiler
v.msvc.exe -o v.gcc.exe compiler
setlocal EnableDelayedExpansion
for /r . %%x in (*_test.v) do (
  v -o test.exe -debug %%x
  if !ERRORLEVEL! NEQ 0 goto :fail
)
for /r . %%x in (*_test.v) do (
  v.msvc.exe -o test.exe -debug %%x
  if !ERRORLEVEL! NEQ 0 goto :fail
)
for /r . %%x in (*_test.v) do (
  v.msvc.2.exe -o test.exe -debug %%x
  if !ERRORLEVEL! NEQ 0 goto :fail
)
for /r . %%x in (*_test.v) do (
  v.gcc.exe -o test.exe -debug %%x
  if !ERRORLEVEL! NEQ 0 goto :fail
)
goto :done

:fail
exit /b 1

:done
