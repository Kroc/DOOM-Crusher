@ECHO OFF

REM # outputs to screen and log file:
REM ====================================================================================================================

SET "LOG_FILE=%~dp0"
IF "%LOG_FILE:~-1,1%" == "\" SET "LOG_FILE=%LOG_FILE:~0,-1%"
SET "LOG_FILE=%LOG_FILE%\log.txt"

REM # allow the parameter string to include exclamation marks
SETLOCAL DISABLEDELAYEDEXPANSION
SET "ECHO=%~1"

REM # now allow the parameter string to be displayed without trying to "execute" it
SETLOCAL ENABLEDELAYEDEXPANSION

REM # check for blank line
IF "!ECHO!" == "" (
	ECHO:
	ECHO:>> %LOG_FILE%
) ELSE (
	ECHO !ECHO!
	ECHO !ECHO!>> %LOG_FILE%
)
