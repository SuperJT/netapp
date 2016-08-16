REM (c) Copyright 2015 NetApp. All rights reserved.
REM Author:       Chris Hurley <churley@netapp.com>
REM Date:         2015-10-20 
REM Description:  Debugging utility to capture additional logs related
REM to connections made by an unusual IPv4 address
REM
REM WARNING: this utility should only be used under the guidance of NetApp
REM support personnel. If used for a commonly used IP, the /tmp partition
REM may fill up.
REM
REM Run this script from the systemshell on cDOT filer.
REM This will have to be run interactively and cannot be
REM invoked from an SSH session.  
REM ***************CAUTION*************
REM This can quickly fill up the node's root volume!!!!!
REM Recommend that there is a separate volume set up to 
REM accept the tars of the sktlogs!!!
REM
REM **************MORE CAUTIONS!!!!!!!!!!!!
REM
REM  IF YOU CTRL-C THIS SCRIPT, YOU WILL NEED TO CLEAN UP
REM  ALL THE THINGS THIS SCRIPT DOES!!!!!!!!!!!!!!!!!!!!!
REM
REM
REM
REM In order to run this script properly in systemshell use nohup!!!!
REM
REM  nohup ./pkttroll.sh &
REM
REM =============================================
REM 	Set global Variables and declarations
REM =============================================
setlocal enableextensions enabledelayedexpansion
SET puttydir="C:\Path\To\Putty\"
SET SAVEPATH=\\christoh-1\vol_ntfs\pktttest
SET CRASHDIR=\\christoh-1\c$\etc\crash
SET PKTTOPTS="-d /etc/crash -i 10.10.10.10"
SET passwd=P@ssw0rd
SET username=root
SET filerip=10.10.10.10
SET ITERATIONS=96
SET ITERTIME=15
SET NUMFILES=5
SET HASH=%DATE:~6,4%%DATE:~3,2%%DATE:~0,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
SET /A START=(%TIME:~0,2%)*360000 + (%TIME:~3,2%)*6000 + (%TIME:~6,2%)*100 + (%TIME:~9,2%)
SET TMPDIR=\\christoh-1\c$\etc\crash\tmp_pkttroll_%HASH%
SET DEBUGME=true
SET LOGFILE=%TMPDIR%/tmp_pkttroll_%HASH%.log

:Start
REM
REM ------------------------------------------------
REM
REM Does the savepath exist?
IF NOT EXIST %savepath% (
	mkdir %SAVEPATH%
)

mkdir %TMPDIR%
ECHO Starting pkttroll.sh at %date% %time% >>%logfile% 2>&1
"%puttydir%"Plink.exe -ssh -pw %passwd% %uname%@%filerip% "options autosupport.doit Starting pktt collection from date %HASH%"
REM 
REM ------------------------------------------------
REM Calculate the total end of the iteration by multiplying
REM the number of iterations by the iteration time
REM multiply by 60 and add to current epoch
SET /A ITERSTART=(%TIME:~0,2%)*360000 + (%TIME:~3,2%)*6000 + (%TIME:~6,2%)*100 + (%TIME:~9,2%)
SET /A TOTALITER=(%ITERATIONS%)*(%ITERTIME%)
ECHO Total iteration time %TOTALITER% >>%logfile% 2>&1
SET /A ITEREND=(%ITERSTART%) + (%TOTALITER%*60)
echo End of script should be %ITEREND% >>%logfile% 2>&1
pause
REM WHILE THE DATE IS LESSTHAN THE ITEREND.....   DO THE PKTT AND CHECK THE FILESIZE
:While
SET /A CURRTIME=(%TIME:~0,2%)*360000 + (%TIME:~3,2%)*6000 + (%TIME:~6,2%)*100 + (%TIME:~9,2%)
if %CURRTIME% LSS %ITEREND% (
	echo Starting pktt on %date% %time% >>%logfile% 2>&1
	REM Start the pktt
	"%puttydir%"Plink.exe -ssh -pw %passwd% %uname%@%filerip% "pktt start all -d /etc/crash/tmp_pkttroll_$HASH %pkttopts%"
	REM CHECK FOR NUMFILES number of trc files
	REM if there's more than NUMFILES, delete the oldest
	for /F "skip=%NUMFILES" %%a in ('dir /b /o-d %TMPDIR%\losk*') do (set DELSTR=%%a)
	SET FILENAME=%DATE:~6,4%%DATE:~3,2%%DATE:~0,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
	echo File searchstring %FILENAME%  >>%logfile% 2>&1
	IF DEFINED %DELSTR% (
		REM if DELSTR is defined, we're assuming we have more than NUMFILES in the dir
		REM then we move the files off and delete the old files
		for /F %%b in ('dir /b /o-d )
	
) 
Timeout /T 900
 
Plink.exe -ssh -pw <enter password here> <username>@<ip of clustershell> " system node run -node <nodename> -command "pktt stop all""
 
goto start 
:End
ENDLOCAL