@echo off
title R36S DTB Selector
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0\dtb\select_device.ps1"
pause