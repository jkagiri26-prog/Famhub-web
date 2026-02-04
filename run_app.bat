@echo off
echo Opening FamHub App Preview in Chrome...
start chrome "file://%~dp0index.html"
echo.
echo If Chrome doesn't open, manually open: %~dp0index.html
echo.
pause