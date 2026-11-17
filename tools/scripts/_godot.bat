@echo off
rem Uso interno de jogar.bat e studio.bat: acha o Godot e prepara o projeto.
rem Define GODOT_EXE e PROJECT_DIR. Retorna 1 (com mensagem) se o Godot nao for encontrado.
chcp 65001 >nul

set "PROJECT_DIR=%~dp0..\..\godot"
set "GODOT_EXE="
set "GODOT_WANTED="
if exist "%~dp0..\..\.godot-version" set /p GODOT_WANTED=<"%~dp0..\..\.godot-version"

if defined GODOT (
    if exist "%GODOT%" (
        set "GODOT_EXE=%GODOT%"
    ) else (
        echo.
        echo ERRO: a variável GODOT aponta para um arquivo que não existe:
        echo   %GODOT%
        goto :not_found_help
    )
)
if not defined GODOT_EXE (
    for %%N in (godot.exe godot4.exe godot.cmd godot.bat) do (
        if not defined GODOT_EXE for %%P in ("%%~$PATH:N") do if not "%%~P"=="" set "GODOT_EXE=%%~P"
    )
)
if not defined GODOT_EXE (
    echo.
    echo ERRO: Godot não encontrado.
    goto :not_found_help
)

if not exist "%PROJECT_DIR%\.godot" (
    echo Primeira execução: importando o projeto ^(pode levar um minuto^)...
    "%GODOT_EXE%" --headless --path "%PROJECT_DIR%" --import >nul 2>nul
)
exit /b 0

:not_found_help
echo.
echo Instale o Godot %GODOT_WANTED% ^(versão padrão, sem .NET^): https://godotengine.org/download
echo Depois, faça UMA destas opções:
echo   - coloque a pasta do Godot no PATH, com o executável chamado "godot.exe"; ou
echo   - crie a variável de ambiente GODOT com o caminho completo do executável. Exemplo:
echo       setx GODOT "C:\Godot\Godot_v%GODOT_WANTED%-stable_win64.exe"
echo     ^(feche e abra o terminal de novo depois do setx^)
echo.
pause
exit /b 1
