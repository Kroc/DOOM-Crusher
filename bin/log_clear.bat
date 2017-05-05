@ECHO OFF & SETLOCAL ENABLEEXTENSIONS DISABLEDELAYEDEXPANSION

REM # log_clear.bat
REM ====================================================================================================================
REM # clears the log file

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

SET "LOG_FILE=%HERE%\log.txt"
IF EXIST "%LOG_FILE%" DEL /F "%LOG_FILE%"
