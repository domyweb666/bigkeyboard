@echo off
call "C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Auxiliary/Build/vcvars64.bat" >nul
cd /d "%~dp0"
set V=vendor
set SRC=vendor/ParselessLM.cpp vendor/ParselessPhraseDB.cpp vendor/Mandarin/Mandarin.cpp vendor/gramambular2/reading_grid.cpp win_mmap.cpp main.cpp random.cpp
for %%d in (obj objt objd) do if not exist %%d mkdir %%d
cl /nologo /utf-8 /std:c++17 /O2 /EHsc /DNDEBUG /MP /I. /Istub /Ivendor /Ireal /Foobj/ /Fe:test.exe %SRC% || exit /b 1
if "%1"=="fast" exit /b 0
cl /nologo /utf-8 /std:c++17 /O2 /EHsc /DNDEBUG /DTUNE /MP /I. /Istub /Ivendor /Ihdr /Foobjt/ /Fe:tune.exe %SRC% || exit /b 1
cl /nologo /utf-8 /std:c++17 /O1 /EHsc /D_ITERATOR_DEBUG_LEVEL=1 /MP /I. /Istub /Ivendor /Ireal /Foobjd/ /Fe:check.exe %SRC% || exit /b 1
