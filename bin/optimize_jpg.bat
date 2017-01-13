@ECHO OFF

REM # optimize_jpg.bat
REM ====================================================================================================================
REM # optimizes a single JPG file

REM # %1 - filepath to a JPG / JPEG file

REM # any parameter?
REM --------------------------------------------------------------------------------------------------------------------
IF "%~1" == "" (
	ECHO optimize_jpg.bat - Kroc Camen
	ECHO:
	ECHO Usage:
	ECHO:
	ECHO     optimize_jpg.bat ^<filepath^>
	ECHO:
	ECHO Notes:
	ECHO:
	ECHO     Optimizes a JPG file without any reduction in quality.
	ECHO:
	GOTO:EOF
)

REM # file missing?
REM --------------------------------------------------------------------------------------------------------------------
IF NOT EXIST "%~1" (
	ECHO optimize_jpg.bat - Kroc Camen
	ECHO:
	ECHO Error:
	ECHO:
	ECHO     File given does not exist.
	ECHO:
	ECHO Command:
	ECHO:
	ECHO     optimize_jpg.bat %0
	ECHO:
	ECHO Current Directory:
	ECHO:
	ECHO     %CD%
	ECHO: 
	EXIT /B 1
)

REM ====================================================================================================================
REM # we cannot get the updated size of the file without just-in-time variable expansion
SETLOCAL ENABLEDELAYEDEXPANSION

REM # path of this script
SET "HERE=%~dp0"
IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"

REM # absolute path of the JPG file
SET "JPG_FILE=%~f1"

REM # jpegtran:
SET "BIN_JPEG=%HERE%\jpegtran\jpegtran.exe"
REM # -optimize		: optimize without quality loss
REM # -copy none	: don't keep any metadata
SET EXEC_JPEGTRAN="%BIN_JPEG%" -optimize -copy none "%JPG_FILE%" "%JPG_FILE%"

REM # display file name and current file size
CALL :status_oldsize "%JPG_FILE%"

REM # done this file before?
REM --------------------------------------------------------------------------------------------------------------------
CALL "%HERE%\hash_check.bat" "%JPG_FILE%"
REM # the file is in the hash-cache, we can skip it
IF %ERRORLEVEL% EQU 0 (
	ECHO : skipped ^(cache^)
	EXIT /B 0
)

REM # do the actual optimization
%EXEC_JPEGTRAN%  >NUL 2>&1
IF ERRORLEVEL 1 (
	REM # cap the status line
	ECHO ^^!! error ^<pngout^>
) ELSE (
	REM # add the file to the hash-cache
	CALL "%HERE%\hash_add.bat" "%JPG_FILE%"
	REM # cap status line with the new file size
	CALL :status_newsize "%JPG_FILE%"
)
EXIT /B 0

REM ====================================================================================================================

:status_oldsize
	REM # prepare the columns for output
	SET "JPG_COLS=                                                                               "
	SET "JPG_COL1_W=45"
	SET "JPG_COL1=!JPG_COLS:~0,%JPG_COL1_W%!"
	REM # prepare the status line
	SET "JPG_LINE=%~nx1%JPG_COL1%"
	REM # get the current file size
	SET "JPG_SIZE_OLD=%~z1"
	REM # right-align it
	CALL :format_filesize_bytes JPG_LINE_OLD %JPG_SIZE_OLD%
	REM # output the status line (without new line)
	<NUL (SET /P "$=- !JPG_LINE:~0,%JPG_COL1_W%! %JPG_LINE_OLD% ")
	GOTO:EOF

:status_newsize
	SET "JPG_SIZE_NEW=%~z1"
	REM # right-align the number
	CALL :format_filesize_bytes JPG_LINE_NEW %JPG_SIZE_NEW%
	REM # calculate percentage change
	IF "%JPG_SIZE_NEW%" == "%JPG_SIZE_OLD%" (
		SET /A JPG_SAVED=0
	) ELSE (
		SET /A JPG_SAVED=100-100*JPG_SIZE_NEW/JPG_SIZE_OLD
	)
	REM # align and print
	SET "JPG_SAVED=   %JPG_SAVED%%%"
	ECHO - %JPG_SAVED:~-3% = %JPG_LINE_NEW%
	GOTO:EOF

:format_filesize_bytes
	SETLOCAL
	REM # add the thousands separators to the number
	CALL :format_number_thousands RESULT %~2
	REM # right-align the number
	SET "RESULT=           %RESULT%"
	SET "RESULT=%RESULT:~-11%"
	ENDLOCAL & SET "%~1=%RESULT%"
	GOTO:EOF
	
:format_number_thousands
	SETLOCAL
	SET "RESULT="
	SET "NUMBER=%~2"
	:number_thousands_loop
	SET "RESULT=%NUMBER:~-3%%RESULT%"
	SET "NUMBER=%NUMBER:~0,-3%"
	IF DEFINED NUMBER SET "RESULT=,%RESULT%" & GOTO :number_thousands_loop 
	SET "%~1=%RESULT%" 
	ENDLOCAL & SET "%~1=%RESULT%"
	GOTO:EOF