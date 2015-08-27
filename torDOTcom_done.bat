@echo off
set logfile="S:\resources\logs\pitstoplog.txt"
@echo on
@echo %date% %time% >> %logfile% 2>&1

C:\Ruby193\bin\ruby.exe S:\resources\bookmaker_scripts\pitstop_watch\torDOTcom_pitstop_output.rb '%1' >> %logfile% 2>&1