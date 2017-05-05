@ECHO OFF & SETLOCAL ENABLEEXTENSIONS DISABLEDELAYEDEXPANSION

REM # log_echo.bat
REM ====================================================================================================================
REM # outputs to screen and log file

REM # init
REM --------------------------------------------------------------------------------------------------------------------
REM # path of this script:
REM # (must be done before using `SHIFT`)
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"

REM # check for an echo parameter (enables ECHO)
SET "ECHO="
IF /I "%~1" == "/ECHO" (
	REM # the "/ECHO" parameter will be passed to all called scripts too
	SET "ECHO=/ECHO"
	REM # re-enable ECHO
	ECHO ON
	REM # remove the parameter
	SHIFT
)

REM ====================================================================================================================

REM # location of the log file
SET "LOG_FILE=%HERE%\log.txt"

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
