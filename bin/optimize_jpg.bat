@ECHO OFF & SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

REM # optimize_jpg.bat
REM ====================================================================================================================
REM # optimizes a single JPG file

REM # %1 - filepath to a JPG / JPEG file

REM --------------------------------------------------------------------------------------------------------------------
CALL :init

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
	ECHO     optimize_jpg.bat %*
	ECHO:
	ECHO Current Directory:
	ECHO:
	ECHO     %CD%
	ECHO: 
	EXIT /B 1
)

REM ====================================================================================================================

REM # absolute path of the JPG file
SET "JPG_FILE=%~f1"

REM # jpegtran:
SET "BIN_JPEG=%HERE%\jpegtran\jpegtran.exe"
REM # -optimize		: optimize without quality loss
REM # -copy none	: don't keep any metadata
SET EXEC_JPEGTRAN="%BIN_JPEG%" -optimize -copy none "%JPG_FILE%" "%JPG_FILE%"

REM # display file name and current file size
CALL :display_status_left "%JPG_FILE%"

REM # done this file before?
REM --------------------------------------------------------------------------------------------------------------------
REM # hashing commands:
SET HASH_TRY="%HERE%\hash_check.bat" "jpg"
SET HASH_ADD="%HERE%\hash_add.bat" "jpg"

REM # check the file in the hash-cache
CALL %HASH_TRY% "%JPG_FILE%"
REM # the file is in the hash-cache, we can skip it
IF %ERRORLEVEL% EQU 0 (
	CALL :display_status_msg ": skipped (cache)"
	EXIT /B 0
)

REM ====================================================================================================================

REM # do the actual optimization
%EXEC_JPEGTRAN%  >NUL 2>&1
IF ERRORLEVEL 1 (
	REM # cap the status line
	CALL :display_status_msg "^! error <jpegtran>"
	REM # if JPG optimisation failed return an error state; if the JPG was from a WAD or PK3 then these
	REM # will *not* be cached so that they will always be retried in the future until there are no errors
	REM # (we do not want to write off a WAD or PK3 as "done" when there are potential savings remaining)
	EXIT /B 1
) ELSE (
	REM # add the file to the hash-cache
	CALL %HASH_ADD% "%JPG_FILE%"
	REM # cap status line with the new file size
	CALL :display_status_right "%JPG_FILE%"
)
EXIT /B 0


REM # functions:
REM ====================================================================================================================

:init
	REM # path of this script:
	REM # (must be done before using `SHIFT`)
	SET "HERE=%~dp0"
	REM # always remove trailing slash
	IF "%HERE:~-1,1%" == "\" SET "HERE=%HERE:~0,-1%"
	REM # logging commands:
	SET LOG="%HERE%\log.bat"
	SET LOG_ECHO="%HERE%\log_echo.bat"
	GOTO:EOF

:filesize
	REM # get a file size (in bytes):
	REM # 	%1 = variable name to set
	REM # 	%2 = filepath
	REM ------------------------------------------------------------------------------------------------------------
	SET "%~1=%~z2"
	GOTO:EOF

:display_status_left
	REM # outputs the status line up to the original file's size:
	REM #	%1 = filepath
	REM ------------------------------------------------------------------------------------------------------------
	REM # prepare the columns for output
	SET "COLS=                                                                               "
	SET "COL1_W=45"
	SET "COL1=!COLS:~0,%COL1_W%!"
	REM # prepare the status line
	SET "LINE=%~nx1%COL1%"
	REM # get the current file size
	CALL :filesize SIZE_OLD "%~1"
	REM # right-align it
	CALL :format_filesize_bytes LINE_OLD %SIZE_OLD%
	REM # formulate the line
	SET "STATUS_LEFT=* !LINE:~0,%COL1_W%! %LINE_OLD% "
	REM # output the status line (without carriage-return)
	<NUL (SET /P "$=%STATUS_LEFT%")
	GOTO:EOF

:display_status_right
	REM # assuming that the left-hand status is already displayed,
	REM # append the size-reduction in percentage and new file size,
	REM # and output the complete status line to the log
	REM #
	REM #	%1 = filepath
	REM ------------------------------------------------------------------------------------------------------------
	REM # get the updated file size
	CALL :filesize SIZE_NEW "%~1"
	REM # no change in size?
	IF %SIZE_NEW% EQU %SIZE_OLD% (
		SET "STATUS_RIGHT==  0%% : same size"
	) ELSE (
		CALL "%HERE%\get_percentage.bat" SAVED %SIZE_OLD% %SIZE_NEW%
		SET "SAVED=   !SAVED!"
		IF %SIZE_NEW% GTR %SIZE_OLD% (
			SET "SAVED=+!SAVED:~-3!"
		) ELSE (
			SET "SAVED=-!SAVED:~-3!"
		)
		REM # format & right-align the new file size
		CALL :format_filesize_bytes LINE_NEW %SIZE_NEW%
		REM # formulate the line
		SET "STATUS_RIGHT=!SAVED!%% = !LINE_NEW! "
	)
	REM # output the remainder of the status line and log the complete status line
	ECHO %STATUS_RIGHT%
	CALL %LOG% "%STATUS_LEFT%%STATUS_RIGHT%"
	GOTO:EOF
	
:display_status_msg
	REM # append a message to the status line and also output it to the log whole:
	REM # 	%1 = message
	REM ------------------------------------------------------------------------------------------------------------
	REM # allow the parameter string to include exclamation marks
	SETLOCAL DISABLEDELAYEDEXPANSION
	SET "ECHO=%~1"
	REM # now allow the parameter string to be displayed without trying to "execute" it
	SETLOCAL ENABLEDELAYEDEXPANSION
	REM # (note that the status line is displayed in two parts in the console, before and after file optimisation,
	REM #  but needs to be output to the log file as a single line)
	ECHO !ECHO!
	CALL %LOG% "%STATUS_LEFT%!ECHO!"
	ENDLOCAL & GOTO:EOF
	
:format_filesize_bytes
	REM ------------------------------------------------------------------------------------------------------------
	SETLOCAL
	REM # add the thousands separators to the number
	CALL :format_number_thousands RESULT %~2
	REM # right-align the number
	SET "RESULT=           %RESULT%"
	SET "RESULT=%RESULT:~-11%"
	ENDLOCAL & SET "%~1=%RESULT%"
	GOTO:EOF
	
:format_number_thousands
	REM ------------------------------------------------------------------------------------------------------------
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