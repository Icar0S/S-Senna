@echo off
rem Roda o S-SENNA STUDIO a partir do código-fonte (duplo clique ou pelo terminal).
rem Procura o Godot na variável GODOT ou no PATH. Argumentos extras vão para o Studio.
setlocal
call "%~dp0_godot.bat"
if errorlevel 1 exit /b 1
"%GODOT_EXE%" --path "%PROJECT_DIR%" -- --studio %*
exit /b %errorlevel%
