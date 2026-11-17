@echo off
rem Roda o JOGO a partir do código-fonte (duplo clique ou pelo terminal).
rem Procura o Godot na variável GODOT ou no PATH. Argumentos extras vão para o Godot.
setlocal
call "%~dp0_godot.bat"
if errorlevel 1 exit /b 1
"%GODOT_EXE%" --path "%PROJECT_DIR%" %*
exit /b %errorlevel%
